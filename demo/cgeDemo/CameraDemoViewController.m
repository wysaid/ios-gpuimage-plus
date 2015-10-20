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

static const char* const s_functionList[] = {
    "mask", //0
    "暂停", //1
    "人脸检测", //2
    "预处理", //3
};

static const int s_functionNum = sizeof(s_functionList) / sizeof(*s_functionList);

@interface CameraDemoViewController() <CGEFrameProcessingDelegate>
@property (weak, nonatomic) IBOutlet UIButton *quitBtn;
@property (weak, nonatomic) IBOutlet UISlider *intensitySlider;
@property CGECameraViewHandler* myCameraViewHandler;
@property (nonatomic) UIScrollView* myScrollView;
@property (nonatomic) GLKView* glkView;
@property (nonatomic) int currentFilterIndex;
@property (nonatomic) NSString* pathToMovie;
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
        
    } filterConfig:g_effectConfig[_currentFilterIndex] filterIntensity:1.0 isFrontCameraMirrored:YES];
}

- (IBAction)recordingBtnClicked:(UIButton*)sender {
    
    if([_myCameraViewHandler isRecording])
    {
        [_myCameraViewHandler endRecording:^{
            NSLog(@"End recording...\n");
        }];
        
        [sender setTitle:@"录制结束" forState:UIControlStateNormal];
        NSURL *outputURL = [NSURL URLWithString:_pathToMovie];
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL])
        {
            [library writeVideoAtPathToSavedPhotosAlbum:outputURL completionBlock:^(NSURL *assetURL, NSError *error)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     
                     if (error) {
                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                                        delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                         [alert show];
                     } else {
                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                                        delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                         [alert show];
                     }
                 });
             }];
        }
        
        
    }
    else
    {
        unlink([_pathToMovie UTF8String]);
        NSURL *movieURL = [NSURL fileURLWithPath:_pathToMovie];
        [_myCameraViewHandler startRecording:movieURL size:CGSizeMake(480, 640)];
        [sender setTitle:@"正在录制" forState:UIControlStateNormal];
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


- (void)viewDidLoad
{
    [super viewDidLoad];
    cgeSetLoadImageCallback(loadImageCallback, loadImageOKCallback, nil);
    
    _pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
    
    CGRect rt = [[UIScreen mainScreen] bounds];
    
    CGRect sliderRT = [_intensitySlider bounds];
    sliderRT.size.width = rt.size.width;
    [_intensitySlider setFrame:sliderRT];
    
    CGFloat x, y, w = 480.0, h = 640.0;
    
    CGFloat scaling = MIN(rt.size.width / (float)w, rt.size.height / (float)h);
    
    w *= scaling;
    h *= scaling;
    
    x = (rt.size.width - w) / 2.0;
    y = (rt.size.height - h) / 2.0;
    
    _glkView = [[GLKView alloc] initWithFrame:CGRectMake(x, y, w, h)];
    
    _myCameraViewHandler = [[CGECameraViewHandler alloc] initWithGLKView:_glkView];
    
    if([_myCameraViewHandler setupCamera: AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront isFrontCameraMirrored:YES])
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
    CGFloat x, y, w = 480.0, h = 640.0;
    
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
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    [_glkView setFrame:CGRectMake(x, y, w, h)];
    [UIView commitAnimations];
}

#pragma mark - CGEFrameProcessingDelegate

- (BOOL)processingHandle:(void *)data width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow channels:(int)channels
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
            //            byteData[pixelPos + 3] = 255;
        }
    }
    
    return YES;
}

- (BOOL)requireDataWriting
{
    return YES;
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
                [_myCameraViewHandler enableFaceDetect:YES showFaceRects:YES];
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
            
        default:
            break;
    }
}

@end
