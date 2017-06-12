/*
 * cgeVideoCameraViewHandler.m
 *
 *  Created on: 2015-9-6
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeVideoCameraViewHandler.h"
#import "cgeUtilFunctions.h"

#define ROTATE_RECT(rt) \
do\
{\
    CGFloat temp = rt.size.width;\
    rt.size.width = rt.size.height;\
    rt.size.height = temp;\
    temp = rt.origin.x;\
    rt.origin.x = rt.origin.y;\
    rt.origin.y = temp;\
}while(0)

/////////////////////////////////////////////

@interface CGECameraViewHandler()
{
    CGRect _viewArea;
    BOOL _shouldUpdateViewport;
    BOOL _firstFrame, _firstFrameCalled;
}

@property(weak, nonatomic) GLKView* glkView;

@end

@implementation CGECameraViewHandler

- (id)init
{
//    self = [super init];
//
//    [self setup];

    return nil;
}

- (id)initWithGLKView:(GLKView*)glkView
{
    self = [super init];
    
    [self setup];
    [self setGlkView:glkView];

    return self;
}

- (void)setup
{
    _cameraRecorder = [[CGECameraFrameRecorder alloc] initWithContext:[CGESharedGLContext globalGLContext]];
    [_cameraRecorder setUpdateDelegate:self];
    
    _shouldResetViewport = NO;
    _shouldUpdateViewport = NO;
    _firstFrame = YES;
    _firstFrameCalled = NO;
}

- (void)setGlkView:(GLKView *)glkView
{
    _glkView = glkView;
    [_glkView setDrawableColorFormat:GLKViewDrawableColorFormatRGBA8888];
    [_glkView setContext:[_cameraRecorder.sharedContext context]];
    [_glkView setEnableSetNeedsDisplay:NO];
    [_glkView setBackgroundColor:[UIColor clearColor]];
}

- (void)dealloc
{
    [self clear];
    CGE_NSLog(@"###view handler dealloc...\n");
}

- (void)clear
{
    if(_cameraRecorder != nil)
    {
        [_cameraRecorder clear];
        _cameraRecorder = nil;
    }
    _glkView = nil;
    [EAGLContext setCurrentContext:nil];
}

- (void)fitViewSizeKeepRatio:(BOOL)shouldFit
{
    _shouldUpdateViewport = shouldFit;
    _shouldResetViewport = shouldFit;
}

- (void)_fitViewWithRatio
{
    float viewWidth = _glkView.drawableWidth, viewHeight = _glkView.drawableHeight;
    CGSize sz = [[_cameraRecorder cameraDevice] cameraResolution];
    float scaling;
    
    if([_cameraRecorder isUsingMask])
    {
        scaling = [_cameraRecorder maskAspectRatio];
    }
    else
    {
        scaling = sz.height / sz.width;
    }
    
    float viewRatio = viewWidth / viewHeight;
    float s = scaling / viewRatio;
    
    float w, h;
    
    //撑满全部view(内容大于view)
    if(s > 1.0)
    {
        w = (int)(viewHeight * scaling);
        h = viewHeight;
    }
    else
    {
        w = viewWidth;
        h = (int)(viewWidth / scaling);
    }
    
    _viewArea.size.width = round(w);
    _viewArea.size.height = round(h);
    _viewArea.origin.x = round((viewWidth - w) / 2.0);
    _viewArea.origin.y = round((viewHeight - h) / 2.0);
    _shouldResetViewport = NO;
}

- (void)frameUpdated
{
    if(_firstFrame)
    {
        if(!_firstFrameCalled)
        {
            CGE_NSLog(@"第一帧等待主线程执行...\n");
            dispatch_async(dispatch_get_main_queue(), ^{
                CGE_NSLog(@"第一帧开始执行...\n");
                _firstFrame = NO;
            });
            _firstFrameCalled = YES;
        }
    }
    else
    {
        [_glkView bindDrawable];
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        if(_shouldUpdateViewport)
        {
            if(_shouldResetViewport)
                [self _fitViewWithRatio];
            glViewport(_viewArea.origin.x, _viewArea.origin.y, _viewArea.size.width, _viewArea.size.height);
        }
        
        [_cameraRecorder fastDrawResult];
        [_glkView display];
    }
    
#if defined(_CGE_SHOW_RENDER_FPS_) && _CGE_SHOW_RENDER_FPS_
    
    static double timeCount = 0;
    static int framesCount = 0;
    static double lastTimestamp = 0;
    
    if(lastTimestamp == 0)
        lastTimestamp = CFAbsoluteTimeGetCurrent();
    
    long currentTimestamp = CFAbsoluteTimeGetCurrent();
    
    ++framesCount;
    timeCount += currentTimestamp - lastTimestamp;
    lastTimestamp = currentTimestamp;
    
    if(timeCount >= 1.0) {
        CGE_NSLog(@"当前帧率: %g fps\n", framesCount / timeCount);
        timeCount = 0.0;
        framesCount = 0;
    }
    
#endif
}

- (void)setFilterWithConfig :(const char*) config
{
    [_cameraRecorder setFilterWithConfig:config];
}

- (void)setFilterIntensity :(float)value
{
    [_cameraRecorder setFilterIntensity:value];
}

- (AVCaptureDevicePosition)cameraPosition
{
    return [[_cameraRecorder cameraDevice] cameraPosition];
}

- (BOOL)switchCamera :(BOOL)isFrontCameraMirrored
{
    return [_cameraRecorder switchCamera :isFrontCameraMirrored];
}

- (AVCaptureFlashMode)getFlashMode
{
    return [[_cameraRecorder cameraDevice] flashMode];
}

- (BOOL)setCameraFlashMode :(AVCaptureFlashMode)flashMode
{
    return [[_cameraRecorder cameraDevice] setFlashMode:flashMode];
}

- (AVCaptureTorchMode)getTorchMode
{
    return [[_cameraRecorder cameraDevice] torchMode];
}

- (BOOL)setTorchMode:(AVCaptureTorchMode)torchMode
{
    return [[_cameraRecorder cameraDevice] setTorchMode:torchMode];
}

- (BOOL)setupCamera
{
    return [_cameraRecorder setupCamera];
}

- (BOOL)setupCamera :(NSString*)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition isFrontCameraMirrored:(BOOL)isFrontCameraMirrored authorizationFailed:(void (^)(void))authorizationFailed;
{
    return [_cameraRecorder setupCamera:sessionPreset cameraPosition:cameraPosition isFrontCameraMirrored:isFrontCameraMirrored authorizationFailed:authorizationFailed];
}

- (BOOL)focusPoint:(CGPoint)point
{
    return [_cameraRecorder focusPoint:point];
}

- (CGECameraDevice*) cameraDevice
{
    return [_cameraRecorder cameraDevice];
}

- (void)stopCameraSync
{
    if([[_cameraRecorder cameraDevice] captureIsRunning])
    {
        [_cameraRecorder.sharedContext syncProcessingQueue:^{
            [[_cameraRecorder cameraDevice] stopCameraCapture];
        }];
    }
}

- (void)setCameraSessionPreset:(NSString *)sessionPreset
{
    [[_cameraRecorder cameraDevice] setCaptureSessionPreset:sessionPreset];

    if(_shouldUpdateViewport)
        _shouldResetViewport = YES;
}

- (void)takePicture :(void (^)(UIImage*))block filterConfig:(const char*)config filterIntensity:(float)intensity isFrontCameraMirrored:(BOOL)mirrored
{
    [_cameraRecorder takePicture:block filterConfig:config filterIntensity:intensity isFrontCameraMirrored:mirrored];
}

- (void)takeShot:(void (^)(UIImage *))block
{
    [_cameraRecorder takeShot:block];
}

- (void)startRecording :(NSURL*)videoURL size:(CGSize)videoSize
{
    [_cameraRecorder startRecording:videoURL size:videoSize];
}

- (void)startRecording:(NSURL *)videoURL size:(CGSize)videoSize cropArea:(CGRect)cropArea
{
    [_cameraRecorder startRecording:videoURL size:videoSize];
    [[_cameraRecorder videoWriter] setCropArea:cropArea];
}

- (void)endRecording :(void (^)(void))completionHandler
{
    [_cameraRecorder endRecording:completionHandler];
}

- (void)endRecording:(void (^)(void))completionHandler withCompressionLevel:(int)level
{
    [_cameraRecorder endRecording:completionHandler withCompressionLevel:level];
}

- (void)endRecording:(void (^)(void))completionHandler withQuality:(NSString *)quality shouldOptimizeForNetworkUse:(BOOL)shouldOptimize
{
    [_cameraRecorder endRecording:completionHandler withQuality:quality shouldOptimizeForNetworkUse:shouldOptimize];
}

- (void)cancelRecording
{
    [_cameraRecorder cancelRecording];
}

- (BOOL)isRecording
{
    return [_cameraRecorder isRecording];
}

- (void)setMaskUIImage :(UIImage*)image
{
    [_cameraRecorder setMaskUIImage:image];
}

- (void)setMaskTexture :(GLuint)maskTexture textureAspectRatio:(float)aspectRatio
{
    [_cameraRecorder setMaskTexture:maskTexture textureAspectRatio:aspectRatio];
}

- (BOOL)isUsingMask
{
    return [_cameraRecorder isUsingMask];
}

/////////////////////////////////////////////////
// 全局滤镜相关
/////////////////////////////////////////////////

- (void)enableGlobalFilter:(const char *)config
{
    [_cameraRecorder setGlobalFilter:config];
}

- (void)enableFaceBeautify:(BOOL)shouldDo
{
    if(!shouldDo)
    {
        if([_cameraRecorder hasGlobalFilter])
            [_cameraRecorder setGlobalFilter:nil];
        return;
    }
    
    static dispatch_once_t onceToken;
    static BOOL performanceEnough = NO;
    dispatch_once(&onceToken, ^{
        
        CGEDeviceDescription deviceDesc = cgeGetDeviceDescription();
        
        if(deviceDesc.model == CGEDevice_Simulator)
        {
            CGE_NSLog(@"Not a real apple device, skipping the face beautify!\n");
            return ;
        }
        
        switch (deviceDesc.model)
        {
            case CGEDevice_iPod:
                
                //none of the current itouch(<=5) have enough performance.
                //hope for the next generation.
                if(deviceDesc.majorVerion > 5)
                    performanceEnough = YES;
                break;
            case CGEDevice_iPhone:
                //above iphone 4s
                if(deviceDesc.majorVerion > 4)
                    performanceEnough = YES;
                break;
            case CGEDevice_iPad:
                //above ipad2
                if(deviceDesc.majorVerion > 2)
                    performanceEnough = YES;
                break;
            default:
                break;
        }
        
        if(performanceEnough)
        {
            CGE_NSLog(@"😋CPU is enough to process face beautify!\n");
        }
        else
        {
            CGE_NSLog(@"😱CPU is too old to process face beautify! Disabled for now!\n");
        }
    });
    
    if(!performanceEnough)
        return;
    
    CGSize sz = [[_cameraRecorder cameraDevice] cameraResolution];
    
    NSString* config = [NSString stringWithFormat:@"#unpack @beautify face 1.0 %g %g", sz.width, sz.height];
    
    [_cameraRecorder setGlobalFilter:[config UTF8String]];
}

- (void)setGlobalFilterIntensity:(float)intensity
{
    [_cameraRecorder setGlobalFilterIntensity:intensity];
    CGE_NSLog(@"美颜参数值: %g\n", intensity);
}

- (float)globalFilterIntensity
{
    return [_cameraRecorder globalFilterIntensity];
}

- (BOOL)isGlobalFilterEnabled
{
    return [_cameraRecorder hasGlobalFilter];
}

@end














