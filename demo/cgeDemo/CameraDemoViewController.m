//
//  CameraDemoViewController.m
//  cgeDemo
//
//  Created by WangYang on 15/8/31.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "CameraDemoViewController.h"
#import "cgeUtilFunctions.h"
#import "cgeVideoCameraViewHandler.h"
#import "demoUtils.h"
#import <AssetsLibrary/ALAssetsLibrary.h>

#define SHOW_FULLSCREEN 0
#define RECORD_WIDTH 480
#define RECORD_HEIGHT 640

#define _AVCaptureSessionPreset(w, h) AVCaptureSessionPreset ## w ## x ## h
#define AVCaptureSessionPreset(w, h) _AVCaptureSessionPreset(w, h)

static const char* const s_functionList[] = {
    "mask", //0
    "暂停", //1
    "人脸美化", //2
    "预处理", //3
    "截取帧", //4
};

static const int s_functionNum = sizeof(s_functionList) / sizeof(*s_functionList);

@interface CameraDemoViewController() <CGEFrameProcessingDelegate>
@property (weak, nonatomic) IBOutlet UIButton *quitBtn;
@property (weak, nonatomic) IBOutlet UISlider *intensitySlider;
@property CGECameraViewHandler* myCameraViewHandler;
@property (nonatomic) UIScrollView* myScrollView;
@property (nonatomic) GLKView* glkView;
@property (nonatomic) int currentFilterIndex;
@property (nonatomic) NSURL* movieURL;
@end

@implementation CameraDemoViewController
- (IBAction)quitBtnClicked:(id)sender {
    NSLog(@"Camera Demo Quit...");
    [[[_myCameraViewHandler frameRecorder] videoCamera] stopCameraCapture];
    [self dismissViewControllerAnimated:true completion:nil];
    //手动释放， 避免任何引用计数引起的内存泄漏
    [_myCameraViewHandler clear];
    _myCameraViewHandler = nil;
    [CGESharedGLContext clearGlobalGLContext];
}
- (IBAction)intensityChanged:(UISlider*)sender {
    [_myCameraViewHandler setFilterIntensity:[sender value]];
}
- (IBAction)switchCameraClicked:(id)sender {
    [_myCameraViewHandler switchCamera :YES]; //使用handler封装的 switchCamera 方法可以将前置摄像头产生的图像反向
}

- (IBAction)takePicture:(id)sender {
    [_myCameraViewHandler takePicture:^(UIImage* image){
        
        [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
        NSLog(@"拍照完成， 已保存到相册!\n");
        
    } filterConfig:g_effectConfig[_currentFilterIndex] filterIntensity:1.0 isFrontCameraMirrored:YES];
}

- (IBAction)recordingBtnClicked:(UIButton*)sender {
    
    [sender setEnabled:NO];
    
    if([_myCameraViewHandler isRecording])
    {
        void (^finishBlock)(void) = ^{
            NSLog(@"End recording...\n");
            
            [CGESharedGLContext mainASyncProcessingQueue:^{
                [sender setTitle:@"录制完成" forState:UIControlStateNormal];
                [sender setEnabled:YES];
            }];
            
            [self saveVideo:_movieURL];
            
        };
        
        [_myCameraViewHandler endRecording:finishBlock];
    }
    else
    {
        unlink([_movieURL.path UTF8String]);
        [_myCameraViewHandler startRecording:_movieURL size:CGSizeMake(RECORD_WIDTH, RECORD_HEIGHT)];
        [sender setTitle:@"正在录制" forState:UIControlStateNormal];
        [sender setEnabled:YES];
    }
}

- (IBAction)switchFlashLight:(id)sender {
    static AVCaptureFlashMode flashLightList[] = {
        AVCaptureFlashModeOff,
        AVCaptureFlashModeOn,
        AVCaptureFlashModeAuto
    };
    static int flashLightIndex = 0;
    
    ++flashLightIndex;
    flashLightIndex %= sizeof(flashLightList) / sizeof(*flashLightList);
    
    [_myCameraViewHandler setCameraFlashMode:flashLightList[flashLightIndex]];
}

- (void)saveVideo :(NSURL*)videoURL
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:videoURL])
    {
        [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 if (error)
                 {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                 }
                 else
                 {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                 }
             });
         }];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"File format is not compatibale with album!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    cgeSetLoadImageCallback(loadImageCallback, loadImageOKCallback, nil);
    
    _movieURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.mp4"]];
    
    CGRect rt = [[UIScreen mainScreen] bounds];
    
    CGRect sliderRT = [_intensitySlider bounds];
    sliderRT.size.width = rt.size.width;
    [_intensitySlider setFrame:sliderRT];
    
#if SHOW_FULLSCREEN
    
    _glkView = [[GLKView alloc] initWithFrame:rt];
    
#else
    
    CGFloat x, y, w = RECORD_WIDTH, h = RECORD_HEIGHT;
    
    CGFloat scaling = MIN(rt.size.width / (float)w, rt.size.height / (float)h);
    
    w *= scaling;
    h *= scaling;
    
    x = (rt.size.width - w) / 2.0;
    y = (rt.size.height - h) / 2.0;
    
    _glkView = [[GLKView alloc] initWithFrame: CGRectMake(x, y, w, h)];
    
#endif

    _myCameraViewHandler = [[CGECameraViewHandler alloc] initWithGLKView:_glkView];

    if([_myCameraViewHandler setupCamera: AVCaptureSessionPreset(RECORD_HEIGHT, RECORD_WIDTH) cameraPosition:AVCaptureDevicePositionFront isFrontCameraMirrored:YES authorizationFailed:^{
        NSLog(@"未取得相机或者麦克风权限!!");
    }])
    {
        [[_myCameraViewHandler videoCamera] startCameraCapture];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"The Camera Is Not Allowed!"
                                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
    
    [self.view insertSubview:_glkView belowSubview:_quitBtn];
    
    CGRect scrollRT = rt;
    scrollRT.origin.y = scrollRT.size.height - 60;
    scrollRT.size.height = 50;
    _myScrollView = [[UIScrollView alloc] initWithFrame:scrollRT];
    
    CGRect frame = CGRectMake(0, 0, 85, 50);
    
    for(int i = 0; i != s_functionNum; ++i)
    {
        MyButton* btn = [[MyButton alloc] initWithFrame:frame];
        [btn setTitle:[NSString stringWithUTF8String:s_functionList[i]] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [btn.layer setBorderColor:[UIColor redColor].CGColor];
        [btn.layer setBorderWidth:2.0f];
        [btn.layer setCornerRadius:11.0f];
        [btn setIndex:i];
        [btn addTarget:self action:@selector(functionButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [_myScrollView addSubview:btn];
        frame.origin.x += frame.size.width;
    }
    
    frame.size.width = 70;
    
    for(int i = 0; i != g_configNum; ++i)
    {
        MyButton* btn = [[MyButton alloc] initWithFrame:frame];
        
        if(i == 0)
            [btn setTitle:@"原图" forState:UIControlStateNormal];
        else
            [btn setTitle:[NSString stringWithFormat:@"filter%d", i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [btn.layer setBorderColor:[UIColor blueColor].CGColor];
        [btn.layer setBorderWidth:1.5f];
        [btn.layer setCornerRadius:10.0f];
        [btn setIndex:i];
        [btn addTarget:self action:@selector(filterButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [_myScrollView addSubview:btn];
        frame.origin.x += frame.size.width;
    }
    
    _myScrollView.contentSize = CGSizeMake(frame.origin.x, 50);
    
    [self.view addSubview:_myScrollView];
    CGRect btnRect = [_quitBtn bounds];
    btnRect.origin.x = rt.size.width - btnRect.size.width - 10;
    [_quitBtn setFrame:btnRect];
    
    [CGESharedGLContext globalSyncProcessingQueue:^{
        [CGESharedGLContext useGlobalGLContext];
        void cgePrintGLInfo();
        cgePrintGLInfo();
    }];
    
    [_myCameraViewHandler fitViewSizeKeepRatio:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"view appear.");
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    NSLog(@"view disappear.");
}

- (void)filterButtonClicked: (MyButton*)sender
{
    _currentFilterIndex = [sender index];
    NSLog(@"Filter %d Clicked...\n", _currentFilterIndex);
    
    const char* config = g_effectConfig[_currentFilterIndex];
    [_myCameraViewHandler setFilterWithConfig:config];
}

- (void)setMask
{
    CGRect rt = [[UIScreen mainScreen] bounds];
    
    CGFloat x, y, w = RECORD_WIDTH, h = RECORD_HEIGHT;
    
    if([_myCameraViewHandler isUsingMask])
    {
        [_myCameraViewHandler setMaskUIImage:nil];
    }
    else
    {
        UIImage* img = [UIImage imageNamed:@"mask1.png"];
        w = img.size.width;
        h = img.size.height;
        [_myCameraViewHandler setMaskUIImage:img];        
    }
    
    float scaling = MIN(rt.size.width / (float)w, rt.size.height / (float)h);
    
    w *= scaling;
    h *= scaling;
    
    x = (rt.size.width - w) / 2.0;
    y = (rt.size.height - h) / 2.0;
    
    [_myCameraViewHandler fitViewSizeKeepRatio:YES];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    
#if SHOW_FULLSCREEN
    
    [_glkView setFrame:rt];
    
#else
    
    [_glkView setFrame:CGRectMake(x, y, w, h)];
    
#endif
    
    [UIView commitAnimations];
}

- (void)processingData:(void *)data width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow channels:(int)channels
{
    unsigned char* byteData = (unsigned char*)data;
    
    const int stride = 2;//rand() % 3 + 2;
    
    for(int i = 0; i < height; i += stride)
    {
        const int rowStart = bytesPerRow * i;
        int sum = 0;
        for(int j = 0; j < width; j += stride)
        {
            //BGRA
            const int pixelPos = rowStart + j * channels;
            sum += (int)byteData[pixelPos] | (byteData[pixelPos + 1] << 8) | (byteData[pixelPos + 2] << 16);
            byteData[pixelPos] = sum & 0xff;
            byteData[pixelPos + 1] = (sum >> 8) & 0xff;
            byteData[pixelPos + 2] = (sum >> 16) & 0xff;
        }
    }
}

#pragma mark - CGEFrameProcessingDelegate

//- (BOOL)processingHandleData:(void *)data width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow channels:(int)channels
//{
//    [self processingData:data width:width height:height bytesPerRow:bytesPerRow channels:channels];
//    
//    return YES;
//}
//
//- (BOOL)requireDataWriting
//{
//    return YES;
//}

- (BOOL)processingHandleBuffer:(CVImageBufferRef)imageBuffer
{
    CVPixelBufferLockBaseAddress(imageBuffer, 0); //read&write
    size_t outBytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    void *outBuffer = (void *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    [self processingData:outBuffer width:(int)width height:(int)height bytesPerRow:(int)outBytesPerRow channels:4];
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0); //write back
    
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [touches enumerateObjectsUsingBlock:^(UITouch* touch, BOOL* stop) {
        CGPoint touchPoint = [touch locationInView:_glkView];
        CGSize sz = [_glkView frame].size;
        CGPoint transPoint = CGPointMake(touchPoint.x / sz.width, touchPoint.y / sz.height);
        
        [_myCameraViewHandler focusPoint:transPoint];
        NSLog(@"touch position: %g, %g, transPoint: %g, %g", touchPoint.x, touchPoint.y, transPoint.x, transPoint.y);
    }];
}

- (void)functionButtonClick: (MyButton*)sender
{
    NSLog(@"Function Button %d Clicked...\n", [sender index]);
    
    switch ([sender index])
    {
        case 0:
            [self setMask];
            break;
        case 1:
            if([[_myCameraViewHandler videoCamera] captureIsRunning])
            {
                [[_myCameraViewHandler videoCamera] stopCameraCapture];
                [sender setTitle:@"启动相机" forState:UIControlStateNormal];
            }
            else
            {
                [[_myCameraViewHandler videoCamera] startCameraCapture];
                [sender setTitle:@"暂停相机" forState:UIControlStateNormal];
            }
            break;
        case 2:
            if([_myCameraViewHandler faceDetectEnabled])
            {
                [_myCameraViewHandler enableFaceDetect:NO];
                [sender setTitle:@"检测停止" forState:UIControlStateNormal];
            }
            else
            {
                [_myCameraViewHandler enableFaceDetect:YES setupDefaultFilters:YES];
                [sender setTitle:@"正在检测" forState:UIControlStateNormal];
            }

            break;
        case 3:
            if([[_myCameraViewHandler frameRecorder] processingDelegate] == nil)
            {
                [[_myCameraViewHandler frameRecorder] setProcessingDelegate:self];
                [sender setTitle:@"处理中" forState:UIControlStateNormal];
            }
            else
            {
                [[_myCameraViewHandler frameRecorder] setProcessingDelegate:nil];
                [sender setTitle:@"处理停止" forState:UIControlStateNormal];
            }
            break;
        case 4:
        {
            [_myCameraViewHandler takeShot:^(UIImage *image) {
                if(image != nil)
                {
                    [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
                    NSLog(@"截取完成， 已保存到相册!!\n");
                }
                else
                {
                    NSLog(@"截取失败!!!");
                }
            }];
        }
            break;
            
        default:
            break;
    }
}

@end
