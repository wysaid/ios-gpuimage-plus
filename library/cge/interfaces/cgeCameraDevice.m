/*
 * cgeCameraDevice.m
 *
 *  Created on: 2015-8-23
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeCameraDevice.h"

CGE_UNEXPECTED_ERR_MSG(static int sDeviceCount = 0;)

@interface CGECameraDevice ()
{
    AVCaptureDeviceInput* _audioInput;
    AVCaptureAudioDataOutput* _audioOutput;
    
    dispatch_queue_t _cameraProcessingQueue, _audioProcessingQueue;
    
    int _previewWidth, _previewHeight;
    BOOL _isFullYUVRange;
    
    BOOL _captureAsYUV;
}

@end

@implementation CGECameraDevice

@synthesize frameRate = _frameRate;
@synthesize captureSession = _captureSession;

- (id)init
{
    return [self initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
}

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    CGE_UNEXPECTED_ERR_MSG
    (
    if(++sDeviceCount != 1)
    {
        CGE_NSLog(@"\n\n\n❌❌❌❌❌❌❌\n\n 逗比, 你同时创建了 %d 个 camera device, 你在搞笑吗? \n\n❌❌❌❌❌❌❌❌❌❌❌\n", sDeviceCount);
    })
    
    _captureAsYUV = YES;
    
    _cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
    _audioProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0);

    _frameRate = 0;
    
    _capturePaused = NO;
    
    _captureSessionPreset = sessionPreset;
    
//    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
//    if ( !([audioSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord] && ((audioSession.categoryOptions&AVAudioSessionCategoryOptionMixWithOthers) == AVAudioSessionCategoryOptionMixWithOthers)&& ((audioSession.categoryOptions&AVAudioSessionCategoryOptionDefaultToSpeaker) == AVAudioSessionCategoryOptionDefaultToSpeaker))) {
//        
//        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
//        if( ![CGECameraDevice isHeadphone])
//        {
//            [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
//        }
//        [audioSession setActive:YES error:nil];
//    }
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession beginConfiguration];
    
//    _captureSession.usesApplicationAudioSession = YES;
//    _captureSession.automaticallyConfiguresApplicationAudioSession = NO;
    
    [_captureSession setSessionPreset:_captureSessionPreset];
    
    _inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == cameraPosition)
        {
            _inputCamera = device;
        }
    }
    
    if(!_inputCamera)
    {
        _inputCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if(_inputCamera == nil)
            return nil;
    }
    
    NSError* error = nil;
    
    [_inputCamera lockForConfiguration:&error];
    if([_inputCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
        [_inputCamera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    [_inputCamera unlockForConfiguration];
    

    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_inputCamera error:&error];
    
    if(error)
    {
        _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:_inputCamera error:&error];
        if(error)
            return nil;
    }
    
    if([_captureSession canAddInput:_videoInput])
        [_captureSession addInput:_videoInput];
    
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setAlwaysDiscardsLateVideoFrames:YES]; //using cache
    
    if(_captureAsYUV)
    {
        BOOL supportsFullYUVRange = NO;
        NSArray *supportedPixelFormats = _videoOutput.availableVideoCVPixelFormatTypes;
        for (NSNumber *currentPixelFormat in supportedPixelFormats)
        {
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            {
                supportsFullYUVRange = YES;
                break;
            }
        }
        
        if (supportsFullYUVRange)
        {
            [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            _isFullYUVRange = YES;
        }
        else
        {
            [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            _isFullYUVRange = NO;
        }
        
    }
    else
    {
        [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    [_videoOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue];
    
    if([_captureSession canAddOutput:_videoOutput])
    {
        [_captureSession addOutput:_videoOutput];
    }
    else
    {
        CGE_NSLog(@"Add video output failed!\n");
        return nil;
    }
    
    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    if([_captureSession canAddOutput:_stillImageOutput])
    {
        [_stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
        [_captureSession addOutput: _stillImageOutput];
    }
    else
    {
        CGE_NSLog(@"Add still image output failed!\n");
    }
    
    [_captureSession commitConfiguration];
//    [_captureSession startRunning];
    
    CGE_NSLog(@"CGECameraDevice-initWithSessionPreset: %@\n", sessionPreset);
    
    id outputSettings = [_videoOutput videoSettings];
    _cameraResolution.width = [[outputSettings objectForKey:@"Width"] floatValue];
    _cameraResolution.height = [[outputSettings objectForKey:@"Height"] floatValue];
    return self;
}

+ (BOOL)isHeadphoneAvailable
{
    AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
    BOOL flag = NO;
    for (AVAudioSessionPortDescription* desc in [route outputs])
    {
        CGE_NSLog(@"Available port name: %@, type: %@", desc.portName, desc.portType);
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones] || [[desc portType] isEqualToString:AVAudioSessionPortBluetoothA2DP])
            flag = YES;
    }
    return flag;
    
//    UInt32 propertySize = sizeof(CFStringRef);
//    CFStringRef route = nil;
//    OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route);
//    
//    /* Known values of route:
//     * "Headset"
//     * "Headphone"
//     * "Speaker"
//     * "SpeakerAndMicrophone"
//     * "HeadphonesAndMicrophone"
//     * "HeadsetInOut"
//     * "ReceiverAndMicrophone"
//     * "Lineout"
//     */
//    
//    if(status == kAudioSessionNoError && route != nil)
//    {
//        NSString* routeStr = (__bridge NSString*)route;
//        NSRange range = [routeStr rangeOfString:@"Head"];
//        routeStr = nil;
//        CFRelease(route);
//        if(range.location != NSNotFound)
//            return YES;
//    }
//    
//    return NO;
}

- (BOOL)addAudioInputsAndOutputs
{
    
    if (_audioOutput)
        return NO;
    
    [_captureSession beginConfiguration];
    
    _microphoneDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    _audioInput = [AVCaptureDeviceInput deviceInputWithDevice:_microphoneDevice error:nil];
    if ([_captureSession canAddInput:_audioInput])
    {
        [_captureSession addInput:_audioInput];
    }
    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    if ([_captureSession canAddOutput:_audioOutput])
    {
        [_captureSession addOutput:_audioOutput];
    }
    else
    {
        CGE_NSLog(@"Couldn't add audio output");
    }
    [_audioOutput setSampleBufferDelegate:self queue:_audioProcessingQueue];
    
    [_captureSession commitConfiguration];
    
    CGE_NSLog(@"CGECameraDevice-addAudioInputsAndOutputs\n");
    return YES;
    
}

- (id)delegate
{
    return _outputDelegate;
}

- (void)setDelegate: (id<CGECameraDeviceOutputDelegate>)delegate
{
    _outputDelegate = delegate;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
//    CGE_NSLog(@"captureOutput");
    if(![_captureSession isRunning])
        return;
    
    if (captureOutput == _audioOutput)
    {
        //音频处理较快， 可同步处理.
        if(!_capturePaused)
            [_outputDelegate dealAudioSampleBuffer:sampleBuffer];
    }
    else
    {
        //视频处理较慢， 需要异步处理.
        if(!_capturePaused)
            [_outputDelegate dealVideoSampleBuffer:sampleBuffer];
    }
}

- (void)cleanup
{
    if(_captureSession != nil)
    {
        [self stopCameraCapture];
        [_videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
        [_audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
        [self removeInputsAndOutputs];
        
        _outputDelegate = nil;
        _captureSession = nil;
    }
}

- (void)dealloc
{
    CGE_UNEXPECTED_ERR_MSG(--sDeviceCount;)
    [self cleanup];
    CGE_NSLog(@"CGECameraDevice dealloc...\n");
}

- (BOOL)removeAudioInputsAndOutputs
{
    if (!_audioOutput)
        return NO;
    
    [_captureSession beginConfiguration];
    [_captureSession removeInput:_audioInput];
    [_captureSession removeOutput:_audioOutput];
    _audioInput = nil;
    _audioOutput = nil;
    _microphoneDevice = nil;
    [_captureSession commitConfiguration];
    return YES;
}

- (void)removeInputsAndOutputs
{
    [_captureSession beginConfiguration];
    if (_videoInput)
    {
        [_captureSession removeInput:_videoInput];
        [_captureSession removeOutput:_videoOutput];
        _videoInput = nil;
        _videoOutput = nil;
    }
    if (_microphoneDevice != nil)
    {
        [_captureSession removeInput:_audioInput];
        [_captureSession removeOutput:_audioOutput];
        _audioInput = nil;
        _audioOutput = nil;
        _microphoneDevice = nil;
    }
    [_captureSession commitConfiguration];
}

- (void)startCameraCapture
{
    if (![_captureSession isRunning])
    {
//        startingCaptureTime = [NSDate date];
        [self flushResolution];
        [_captureSession startRunning];
    };
}

- (void)stopCameraCapture
{
    if (_captureSession && [_captureSession isRunning])
    {
        [_captureSession stopRunning];
    }
}

- (BOOL)captureIsRunning
{
    return _captureSession && [_captureSession isRunning];
}

- (void)pauseCameraCapture
{
    _capturePaused = YES;
}

- (void)resumeCameraCapture
{
    if(_capturePaused)
    {
        [self flushResolution];
    }
    
    _capturePaused = NO;    
}

- (BOOL)switchCamera
{
    if ([CGECameraDevice hasFrontFacingCameraPresent] == NO)
        return NO;
    
    NSError *error;
    AVCaptureDeviceInput *newVideoInput;
    AVCaptureDevicePosition currentCameraPosition = [[_videoInput device] position];
    
    if (currentCameraPosition == AVCaptureDevicePositionBack)
    {
        currentCameraPosition = AVCaptureDevicePositionFront;
    }
    else
    {
        currentCameraPosition = AVCaptureDevicePositionBack;
    }
    
    AVCaptureDevice *newInputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == currentCameraPosition)
        {
            newInputCamera = device;
            break;
        }
    }
    
    newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newInputCamera error:&error];
    
    BOOL switchOK = NO;
    
    if (newVideoInput != nil)
    {
        [_captureSession beginConfiguration];
        
        [_captureSession removeInput:_videoInput];
        if ([_captureSession canAddInput:newVideoInput])
        {
            [_captureSession addInput:newVideoInput];
            _videoInput = newVideoInput;
            _inputCamera = newInputCamera;
            switchOK = YES;
        }
        else
        {
            [_captureSession addInput:_videoInput];
        }

        [_captureSession commitConfiguration];
    }
    
    id outputSettings = [_videoOutput videoSettings];
    _cameraResolution.width = [[outputSettings objectForKey:@"Width"] floatValue];
    _cameraResolution.height = [[outputSettings objectForKey:@"Height"] floatValue];
    
    return switchOK;
}

- (AVCaptureFlashMode)flashMode
{
    return [_inputCamera flashMode];
}

- (BOOL)setFlashMode :(AVCaptureFlashMode)flashMode
{
    if([_inputCamera hasFlash] && [_inputCamera isFlashModeSupported:flashMode])
    {
        NSError* err = nil;
        if([_inputCamera lockForConfiguration:&err])
        {
            [_inputCamera setFlashMode:flashMode];
            [_inputCamera unlockForConfiguration];
            return YES;
        }
        else
        {
            CGE_NSLog(@"set flash light mode failed: %@", err);
        }
    }

    return NO;
}

- (AVCaptureTorchMode)torchMode
{
    return [_inputCamera torchMode];
}

- (BOOL)setTorchMode:(AVCaptureTorchMode)torchMode
{
    if([_inputCamera hasTorch] && [_inputCamera isTorchModeSupported:torchMode])
    {
        NSError* err = nil;
        if([_inputCamera lockForConfiguration:&err])
        {
            [_inputCamera setTorchMode:torchMode];
            [_inputCamera unlockForConfiguration];
            return YES;
        }
        else
        {
            CGE_NSLog(@"set torch mode failed: %@", err);
        }
    }
    
    return NO;
}

- (AVCaptureFocusMode)focusMode
{
    return [_inputCamera focusMode];
}

- (BOOL)setFocusMode:(AVCaptureFocusMode)focusMode
{
    if([_inputCamera isFocusModeSupported:focusMode])
    {
        NSError* err = nil;
        if([_inputCamera lockForConfiguration:&err])
        {
            [_inputCamera setFocusMode:focusMode];
            [_inputCamera unlockForConfiguration];
            return YES;
        }
        else
        {
            CGE_NSLog(@"set focus mode failed: %@", err);
        }
    }
    
    return NO;
}

- (AVCaptureExposureMode)exposureMode
{
    return [_inputCamera exposureMode];
}

- (BOOL)setExposureMode:(AVCaptureExposureMode)exposureMode
{
    if([_inputCamera isExposureModeSupported:exposureMode])
    {
        NSError* err = nil;
        if([_inputCamera lockForConfiguration:&err])
        {
            [_inputCamera setExposureMode:exposureMode];
            [_inputCamera unlockForConfiguration];
            return YES;
        }
        else
        {
            CGE_NSLog(@"set exposure mode failed: %@", err);
        }
    }
    
    return NO;
}

- (BOOL)focusPoint:(CGPoint)point
{
    if(!([_inputCamera isFocusPointOfInterestSupported] || [_inputCamera isExposurePointOfInterestSupported]))
    {
        CGE_NSLog(@"❕对焦失败!\n");
        return NO;
    }

    if(self.cameraPosition == AVCaptureDevicePositionFront)
    {
        point.y = 1.0 - point.y;
    }

    NSError* err = nil;
    
    if([_inputCamera lockForConfiguration:&err])
    {
        if([_inputCamera isFocusPointOfInterestSupported])
        {
            [_inputCamera setFocusPointOfInterest:point];
            [_inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        else if([_inputCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
        {
            [_inputCamera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
        
        if([_inputCamera isExposurePointOfInterestSupported] && [_inputCamera isExposureModeSupported:AVCaptureExposureModeAutoExpose])
        {
            [_inputCamera setExposurePointOfInterest:point];
            [_inputCamera setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        else if([_inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
        {
            [_inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        
        [_inputCamera unlockForConfiguration];
        CGE_NSLog(@"😋对焦完成!\n");
    }
    
    return YES;
}

- (AVCaptureDevicePosition)cameraPosition
{
    return [[_videoInput device] position];
}

- (void)setCaptureSessionPreset:(NSString *)captureSessionPreset
{
    if([_captureSessionPreset isEqualToString:captureSessionPreset])
    {
        CGE_NSLog(@"❗️重复设定preset， 跳过...\n");
        return;
    }

    if(![_captureSession canSetSessionPreset:captureSessionPreset])
    {
        CGE_NSLog(@"❌unsupported config: %@\n", captureSessionPreset);
        return;
    }

    [_captureSession beginConfiguration];
    
    _captureSessionPreset = captureSessionPreset;
    [_captureSession setSessionPreset:_captureSessionPreset];
    
    [_captureSession commitConfiguration];

    id outputSettings = [_videoOutput videoSettings];
    _cameraResolution.width = [[outputSettings objectForKey:@"Width"] floatValue];
    _cameraResolution.height = [[outputSettings objectForKey:@"Height"] floatValue];

    CGE_NSLog(@"Camera Resolution Changed: %g x %g", _cameraResolution.width, _cameraResolution.height);
}

- (int32_t)frameRate
{
    return _frameRate;
}

- (void)setFrameRate:(int32_t)frameRate
{
    _frameRate = frameRate;
    
    if (_frameRate > 0)
    {
        if ([_inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [_inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [_inputCamera lockForConfiguration:&error];
            if (error == nil)
            {
#if defined(__IPHONE_7_0)
                [_inputCamera setActiveVideoMinFrameDuration:CMTimeMake(1, _frameRate)];
                [_inputCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, _frameRate)];
#endif
            }
            [_inputCamera unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in _videoOutput.connections)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = CMTimeMake(1, _frameRate);
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = CMTimeMake(1, _frameRate);
#pragma clang diagnostic pop
            }
        }
        
    }
    else
    {
        if ([_inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [_inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [_inputCamera lockForConfiguration:&error];
            if (error == nil)
            {
#if defined(__IPHONE_7_0)
                [_inputCamera setActiveVideoMinFrameDuration:kCMTimeInvalid];
                [_inputCamera setActiveVideoMaxFrameDuration:kCMTimeInvalid];
#endif
            }
            [_inputCamera unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in _videoOutput.connections)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = kCMTimeInvalid; // This sets videoMinFrameDuration back to default
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = kCMTimeInvalid; // This sets videoMaxFrameDuration back to default
#pragma clang diagnostic pop
            }
        }
        
    }
}

- (AVCaptureConnection *)videoCaptureConnection {
    for (AVCaptureConnection *connection in [_videoOutput connections] ) {
        for ( AVCaptureInputPort *port in [connection inputPorts] ) {
            if ( [[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                return connection;
            }
        }
    }
    
    return nil;
}

- (void)flushResolution
{
    id outputSettings = [_videoOutput videoSettings];
    _cameraResolution.width = [[outputSettings objectForKey:@"Width"] floatValue];
    _cameraResolution.height = [[outputSettings objectForKey:@"Height"] floatValue];
}

//////////////////////////////////////////////////////

+ (BOOL)isBackFacingCameraPresent
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == AVCaptureDevicePositionBack)
            return YES;
    }
    
    return NO;
}

+ (BOOL)hasFrontFacingCameraPresent
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == AVCaptureDevicePositionFront)
            return YES;
    }
    
    return NO;
}

@end























