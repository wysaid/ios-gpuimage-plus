//
//  CameraDemoViewController.m
//  cgeDemo
//
//  Created by WangYang on 15/8/31.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import <Vision/Vision.h>
#import "cgeUtilFunctions.h"
#import "CameraDemoViewController.h"
#import "cgeVideoCameraViewHandler.h"
#import "demoUtils.h"
#import "cgeGLFunctions.h"
#import "cgeVec.h"

#define SHOW_FULLSCREEN 0
#define RECORD_WIDTH 480
#define RECORD_HEIGHT 640

#define _MYAVCaptureSessionPreset(w, h) AVCaptureSessionPreset ## w ## x ## h
#define MYAVCaptureSessionPreset(w, h) _MYAVCaptureSessionPreset(w, h)

static const char* const s_functionList[] = {
    "ShowFace", //0
};

static const int s_functionNum = sizeof(s_functionList) / sizeof(*s_functionList);

@interface CameraDemoViewController() <CGEFrameProcessingDelegate>
{
    std::vector<CGE::Vec2f> _faceData;
    NSLock* _faceDataLock;
    CGE::ProgramObject* _drawFaceProgram;
    dispatch_semaphore_t _faceDetectSema;
}

@property (weak, nonatomic) IBOutlet UIButton *quitBtn;
@property (weak, nonatomic) IBOutlet UISlider *intensitySlider;
@property CGECameraViewHandler* myCameraViewHandler;
@property (nonatomic) UIScrollView* myScrollView;
@property (nonatomic) GLKView* glkView;
@property (nonatomic) int currentFilterIndex;
@property (nonatomic) NSURL* movieURL;

//This will show you how to do a simple face emoji.
@property (nonatomic) VNSequenceRequestHandler* faceLandMarkHandler;
@property (nonatomic) NSArray<VNDetectFaceLandmarksRequest*>* faceLandMarkRequests;
@end

@implementation CameraDemoViewController
- (IBAction)quitBtnClicked:(id)sender {
    NSLog(@"Camera Demo Quit...");
    [[[_myCameraViewHandler cameraRecorder] cameraDevice] stopCameraCapture];
    [self dismissViewControllerAnimated:true completion:nil];
    //safe clear to avoid memLeaks.
    [_myCameraViewHandler clear];
    _myCameraViewHandler = nil;
    [CGESharedGLContext clearGlobalGLContext];
}
- (IBAction)intensityChanged:(UISlider*)sender {
    float currentIntensity = [sender value] * 3.0f - 1.0f; //[-1, 2]
    [_myCameraViewHandler setFilterIntensity: currentIntensity];
}
- (IBAction)switchCameraClicked:(id)sender {
    [_myCameraViewHandler switchCamera :YES]; //Pass YES to mirror the front camera.

    CMVideoDimensions dim = [[[_myCameraViewHandler cameraDevice] inputCamera] activeFormat].highResolutionStillImageDimensions;
    NSLog(@"Max Photo Resolution: %d, %d\n", dim.width, dim.height);
}

- (IBAction)takePicture:(id)sender {
    [_myCameraViewHandler takePicture:^(UIImage* image){
        [DemoUtils saveImage:image];
        NSLog(@"Take Picture OK, Saved To The Album!\n");
        
    } filterConfig:g_effectConfig[_currentFilterIndex] filterIntensity:1.0f isFrontCameraMirrored:YES];
}

- (IBAction)recordingBtnClicked:(UIButton*)sender {
    
    [sender setEnabled:NO];
    
    if([_myCameraViewHandler isRecording])
    {
        void (^finishBlock)(void) = ^{
            NSLog(@"End recording...\n");
            
            [CGESharedGLContext mainASyncProcessingQueue:^{
                [sender setTitle:@"Rec OK" forState:UIControlStateNormal];
                [sender setEnabled:YES];
            }];
            
            [DemoUtils saveVideo:_movieURL];
            
        };
        
//        [_myCameraViewHandler endRecording:nil];
//        finishBlock();
        [_myCameraViewHandler endRecording:finishBlock withCompressionLevel:0];
    }
    else
    {
        unlink([_movieURL.path UTF8String]);
        [_myCameraViewHandler startRecording:_movieURL size:CGSizeMake(RECORD_WIDTH, RECORD_HEIGHT)];
        [sender setTitle:@"Recording" forState:UIControlStateNormal];
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _movieURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.mp4"]];
    
    CGRect rt = [[UIScreen mainScreen] bounds];
    
    CGRect sliderRT = [_intensitySlider bounds];
    sliderRT.size.width = rt.size.width - 20;
    [_intensitySlider setBounds:sliderRT];
    
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

    if([_myCameraViewHandler setupCamera: MYAVCaptureSessionPreset(RECORD_HEIGHT, RECORD_WIDTH) cameraPosition:AVCaptureDevicePositionFront isFrontCameraMirrored:YES authorizationFailed:^{
        NSLog(@"Not allowed to open camera and microphone, please choose allow in the 'settings' page!!!");
    }])
    {
        [[_myCameraViewHandler cameraDevice] startCameraCapture];
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
    
    CGRect frame = CGRectMake(0, 0, 95, 50);
    
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
    
    _myScrollView.contentSize = CGSizeMake(frame.origin.x, 50);
    
    [self.view addSubview:_myScrollView];
    
    [CGESharedGLContext globalSyncProcessingQueue:^{
        [CGESharedGLContext useGlobalGLContext];
        cgePrintGLInfo();
    }];
    
    [_myCameraViewHandler fitViewSizeKeepRatio:YES];

    //Set to the max resolution for taking photos.
    [[_myCameraViewHandler cameraRecorder] setPictureHighResolution:YES];
    
    ////////////////////////
    
    _faceDetectSema = dispatch_semaphore_create(1);
    _faceDataLock = [[NSLock alloc] init];
    
    _faceLandMarkHandler = [[VNSequenceRequestHandler alloc] init];
    VNDetectFaceLandmarksRequest* req = [[VNDetectFaceLandmarksRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        VNDetectFaceLandmarksRequest* req = (id)request;
        NSArray<VNFaceObservation*>* results = req.results;
        if(results && results.count != 0)
        {
            NSLog(@"find face: %d", (int)results.count);
            [_faceDataLock lock];
            _faceData.clear();
            for(VNFaceObservation* observation in results)
            {
                VNFaceLandmarkRegion2D* landmarks = observation.landmarks.allPoints;
                CGRect boundingBox = observation.boundingBox;
                for(int i = 0; i < landmarks.pointCount; ++i)
                {
                    CGE::Vec2f v;
                    v = landmarks.normalizedPoints[i];
                    v = v * CGE::Vec2f(boundingBox.size.width, boundingBox.size.height) + CGE::Vec2f(boundingBox.origin.x, boundingBox.origin.y);
                    _faceData.push_back(v);
                }
            }
            [_faceDataLock unlock];
        }
    }];
    [req setPreferBackgroundProcessing:NO];
    _faceLandMarkRequests = @[req];
    
    const char* vsh = CGE_SHADER_STRING
    (
     attribute vec2 vPosition;
     void main()
     {
         //flip xy for this demo.
         gl_Position = vec4(1.0 - vPosition * 2.0, 0.0, 1.0);
         gl_PointSize = 10.0;
     }
    );
    
    const char* fsh = CGE_SHADER_STRING_PRECISION_L
    (
    void main()
     {
         gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
     }
    );
    
    [CGESharedGLContext globalSyncProcessingQueue:^{
        [CGESharedGLContext useGlobalGLContext];
        _drawFaceProgram = new CGE::ProgramObject();
        _drawFaceProgram->bindAttribLocation("vPosition", 0);
        if(!_drawFaceProgram->initWithShaderStrings(vsh, fsh))
        {
            delete _drawFaceProgram;
            _drawFaceProgram = nullptr;
        }
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

#pragma mark - CGEFrameProcessingDelegate

- (BOOL)bufferRequestRGBA
{
    return NO;
}

// Draw your own content!
// The content would be shown in realtime, and can be recorded to the video.
- (void)drawProcResults:(void *)handler
{
    if(_drawFaceProgram == nullptr)
    {
        NSLog(@"Invalid face program!");
        return;
    }
    
    [_faceDataLock lock];
    
    if(!_faceData.empty())
    {
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, _faceData.data());
        _drawFaceProgram->bind();
        glDrawArrays(GL_POINTS, 0, (int)_faceData.size());
    }
        
    [_faceDataLock unlock];
}

//The realtime buffer for processing. Default format is YUV, and you can change the return value of "bufferRequestRGBA" to recieve buffer of format-RGBA.
- (BOOL)processingHandleBuffer:(CVImageBufferRef)imageBuffer
{
    if(dispatch_semaphore_wait(_faceDetectSema, DISPATCH_TIME_NOW) == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_faceLandMarkHandler performRequests:_faceLandMarkRequests onCVPixelBuffer:imageBuffer orientation:kCGImagePropertyOrientationRight error:nil];
            dispatch_semaphore_signal(_faceDetectSema);
        });
    }
    return NO;
}

- (void)functionButtonClick: (MyButton*)sender
{
    NSLog(@"Function Button %d Clicked...\n", [sender index]);
    
    switch ([sender index])
    {
        case 0:
            if([[_myCameraViewHandler cameraRecorder] processingDelegate] == nil)
            {
                [[_myCameraViewHandler cameraRecorder] setProcessingDelegate:self];
                [sender setTitle:@"Processing" forState:UIControlStateNormal];
            }
            else
            {
                [[_myCameraViewHandler cameraRecorder] setProcessingDelegate:nil];
                [sender setTitle:@"Stopped" forState:UIControlStateNormal];
            }
            break;
        default:;
    }
}

@end
