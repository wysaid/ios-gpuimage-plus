/*
 * cgeCameraFrameRecorder.mm
 *
 *  Created on: 2015-8-31
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeCameraFrameRecorder.h"
#import "cgeVideoHandlerCV.h"
#import "cgeUtilFunctions.h"
#import "cgeMultipleEffects.h"
#import "cgeCVUtilTexture.h"
#include "cgeAdvancedEffects.h"

#ifdef CGE_USE_OPENAL
#import "cgeALAudioPlayback.h"
#include <vector>
using CGE::CGEALPlayBack;
#endif

using namespace CGE;

@interface CGECameraFrameRecorder()
{
    dispatch_semaphore_t _videoSampleSemaphore;

    CGECVUtilTextureWithFramebuffer* _cgeUtilTexture;
    
    CGEImageFilterInterfaceAbstract* _globalFilter;
    float _globalFilterIntensity;
    
    NSLock* _audioSampleLock;
    std::vector<unsigned char> _vecVoiceBuffer;
#ifdef CGE_USE_OPENAL
    CGEALPlayBack* _voicePlayback;    
    BOOL _isReverbOn;
    int _alAudioSampleRate;
#endif
}

@end

@implementation CGECameraFrameRecorder

- (id)initWithContext :(CGESharedGLContext*)sharedContext
{
    self = [super initWithContext:sharedContext];
    if(self)
    {
        _videoSampleSemaphore = dispatch_semaphore_create(1);

        [self setYUVDrawerRotation:M_PI_2];
        [self setReverseTargetSize:YES];
        
        _audioSampleLock = [[NSLock alloc] init];
#ifdef CGE_USE_OPENAL
        _isReverbOn = NO;
        _alAudioSampleRate = (int)[[AVAudioSession sharedInstance] sampleRate];
        if(_alAudioSampleRate == 0)
            _alAudioSampleRate = 44100;
#endif

//      CGE_FRAMERENDERER_VIDEOHANDLER_TYPE* videoHandler = (CGE_FRAMERENDERER_VIDEOHANDLER_TYPE*)[self getVideoHandler];
//      auto drawer = videoHandler->getYUVDrawer();
//      drawer->setRotation(M_PI_2); //相机默认需要旋转
//      videoHandler->setReverseTargetSize(true);
    }
    return self;
}

- (void)dealloc
{
    [self clear];
    
    CGE_LOG_INFO("###Camera Recorder dealloc...\n");
}

- (void)clear
{
    dispatch_semaphore_wait(_videoSampleSemaphore, DISPATCH_TIME_FOREVER);
    
    if(_cameraDevice != nil)
    {
        [_cameraDevice stopCameraCapture];
        [_cameraDevice cleanup];
        _cameraDevice = nil;
    }
    
    if(self.sharedContext != nil)
    {
        if(_globalFilter != nullptr)
        {
            [self.sharedContext syncProcessingQueue:^{
                [self.sharedContext makeCurrent];
                delete _globalFilter;
                _globalFilter = nullptr;
                
            }];
        }
        [self clearGLData];
    }
    
    _processingDelegate = nil;

#ifdef CGE_USE_OPENAL
    
    if(_voicePlayback != nullptr)
    {
        delete _voicePlayback;
        _voicePlayback = nullptr;
        _vecVoiceBuffer.clear();
    }
    
#endif
    
    dispatch_semaphore_signal(_videoSampleSemaphore);
    [super clear];
}

- (void)clearGLData
{
    if(self.sharedContext != nil)
    {
        [self.sharedContext syncProcessingQueue:^{
            [self.sharedContext makeCurrent];
            
            [_cgeUtilTexture clear];
            _cgeUtilTexture = nil;
        }];
    }
}

- (BOOL)setupGLData: (int)width andHeight:(int)height
{
    _cgeUtilTexture = [CGECVUtilTextureWithFramebuffer makeCVTexture:width height:height bufferPool:nil];
    
    return _cgeUtilTexture != nil;
}

- (void)requestAuthorization :(NSString*)mediaType block:(void (^)(BOOL))block
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
    {
        block(NO);
    }
    else if(authStatus == AVAuthorizationStatusNotDetermined)
    {
        // Explicit user permission is required for media capture, but the user has not yet granted or denied such permission.
        
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:block];
    }
    else
    {
        block(YES);
    }
}

- (BOOL)checkAuthorization
{
    dispatch_semaphore_t authorSemaphore = dispatch_semaphore_create(0);
    __block BOOL authorStatus = NO;
    
    [self requestAuthorization:AVMediaTypeVideo block:^(BOOL granted){
        authorStatus = granted;
        dispatch_semaphore_signal(authorSemaphore);
    }];
    
    //dead lock waiting for authorization.
    
    dispatch_semaphore_wait(authorSemaphore, DISPATCH_TIME_FOREVER);
    
    if(!authorStatus)
        return NO;
    
    [self requestAuthorization:AVMediaTypeAudio block:^(BOOL granted){
        authorStatus = granted;
        dispatch_semaphore_signal(authorSemaphore);
    }];
    
    dispatch_semaphore_wait(authorSemaphore, DISPATCH_TIME_FOREVER);
    
    if(!authorStatus)
        return NO;
    
    return YES;
}

- (BOOL)setupCamera
{
    _cameraDevice = [[CGECameraDevice alloc] init];
    if(_cameraDevice == nil)
        return NO;
    [_cameraDevice addAudioInputsAndOutputs];
    [_cameraDevice setDelegate:self];
    return YES;
}

- (BOOL)setupCamera:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition isFrontCameraMirrored:(BOOL)isFrontCameraMirrored authorizationFailed:(void (^)(void))authorizationFailed
{
    if(![self checkAuthorization])
    {
        if(authorizationFailed)
            authorizationFailed();
        return NO;
    }
    
    _cameraDevice = [[CGECameraDevice alloc] initWithSessionPreset:sessionPreset cameraPosition:cameraPosition];
    if(_cameraDevice == nil)
        return NO;
    [_cameraDevice addAudioInputsAndOutputs];
    [_cameraDevice setDelegate:self];
    
    if(isFrontCameraMirrored && [_cameraDevice cameraPosition] == AVCaptureDevicePositionFront)
    {
        [self setYUVDrawerFlipScale:1.0f flipScaleY:-1.0f];
    }
    return YES;
}

- (BOOL)switchCamera :(BOOL)isFrontCameraMirrored
{
    if([_cameraDevice switchCamera])
    {
        float yFlipScale = (isFrontCameraMirrored && [_cameraDevice cameraPosition] == AVCaptureDevicePositionFront) ? -1.0f : 1.0f;
        [self setYUVDrawerFlipScale:1.0f flipScaleY:yFlipScale];
        return YES;
    }
    return NO;
}

- (BOOL)focusPoint:(CGPoint)point
{
    return [_cameraDevice focusPoint:CGPointMake(point.y, 1.0 - point.x)]; // 修正相机orientation
}

- (void)setProcessingDelegate:(id<CGEFrameProcessingDelegate>)procDelegate
{
    
    if([procDelegate respondsToSelector:@selector(setSharedContext:)])
    {
        [procDelegate setSharedContext:self.sharedContext];
    }
    
    [self.sharedContext syncProcessingQueue:^{
        [_audioSampleLock lock];
        _processingDelegate = procDelegate;
        [_audioSampleLock unlock];
    }];
}

- (void)setExtraRenderingDelegate:(id<CGEFrameExtraRenderingDelegate>)extraRenderingDelegate
{
    if([extraRenderingDelegate respondsToSelector:@selector(setSharedContext:)])
    {
        [extraRenderingDelegate setSharedContext:self.sharedContext];
    }
    
    [self.sharedContext syncProcessingQueue:^{
        _extraRenderingDelegate = extraRenderingDelegate;
    }];
}

#ifdef CGE_USE_OPENAL

- (void)checkForPlayback
{
    if(![CGECameraDevice isHeadphoneAvailable])
    {
        CGE_NSLog(@"⚠️检测到并没有耳机设备， 开启声音回放可能产生啸音!");
    }
}

#endif

- (void)enableVoicePlayback:(BOOL)shouldPlayback
{
#ifdef CGE_USE_OPENAL
    
    if(!shouldPlayback)
    {
        [_audioSampleLock lock];
        delete _voicePlayback;
        _voicePlayback = nullptr;
        _vecVoiceBuffer.clear();
        [_audioSampleLock unlock];
        CGE_NSLog(@"声音回放已关闭!");
    }
    else
    {
        [_audioSampleLock lock];
        if(shouldPlayback && _voicePlayback == nullptr)
        {
            _voicePlayback = CGEALPlayBack::create();
        }
        [_audioSampleLock unlock];
        CGE_NSLog(@"声音回放已打开!");
        
        [self checkForPlayback];
    }
#endif
}

- (BOOL)hasVoicePlayback
{
    return
#ifdef CGE_USE_OPENAL
    _voicePlayback != nullptr;
#else
    NO;
#endif
}

- (void)flushVoicePlayback
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nil)
        _voicePlayback->flush();
#endif
}

- (void)resetVoicePlayback
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nullptr)
    {
        [_audioSampleLock lock];
        delete _voicePlayback;
        _voicePlayback = CGEALPlayBack::create();
        [_audioSampleLock unlock];
        
        [self checkForPlayback];
    }
#endif
}

- (void)enableReverb:(BOOL)useReverb
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nullptr)
    {
        _voicePlayback->setReverbOn((ALint)useReverb);
        _isReverbOn = useReverb;
    }
#endif
}

- (BOOL)hasReverb
{
    return
#ifdef CGE_USE_OPENAL
    _isReverbOn;
#else
    NO;
#endif
}

- (void)setReverbIntensity:(float)reverb
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nullptr)
    {
        _voicePlayback->setSourceReverb(reverb);
    }
#endif
}

- (void)setReverbOcclusion:(float)occlusion
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nullptr)
    {
        _voicePlayback->setSourceOcclusion(occlusion);
    }
#endif
}

- (void)setReverbObstruction:(float)obstruction
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nullptr)
    {
        _voicePlayback->setSourceObstruction(obstruction);
    }
#endif
}

- (void)setRoomType:(unsigned int)room
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nullptr)
    {
        if(room <= 12)
        {
            _voicePlayback->setReverbRoomType(room);
        }
        else
        {
            CGE_LOG_ERROR("Invalid Reverb Room Type!");
        }
    }
#endif
}

- (void)dealAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
#ifdef CGE_USE_OPENAL
    if(_voicePlayback != nullptr || [_processingDelegate respondsToSelector:@selector(processingAudioPCMBuffer:sampleFrames:)])
#else
    if([_processingDelegate respondsToSelector:@selector(processingAudioPCMBuffer:sampleFrames:)])
#endif
    {
        [_audioSampleLock lock];
        
        CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t len = CMBlockBufferGetDataLength(blockBufferRef);
        if(_vecVoiceBuffer.size() < len)
        {
            _vecVoiceBuffer.resize(len);
        }
        CMBlockBufferCopyDataBytes(blockBufferRef, 0, len, _vecVoiceBuffer.data());

        //二次确认， 避免在 voicePlayback == nullptr 时也进行lock操作.
        if([_processingDelegate respondsToSelector:@selector(processingAudioPCMBuffer:sampleFrames:)])
        {
            [_processingDelegate processingAudioPCMBuffer:(short*)_vecVoiceBuffer.data() sampleFrames:(int)len / sizeof(short)];
        }

#ifdef CGE_USE_OPENAL
        if(_voicePlayback != nullptr)
        {
            _voicePlayback->recycle();
            _voicePlayback->play(_vecVoiceBuffer.data(), (int)len, _alAudioSampleRate, AL_FORMAT_MONO16);
        }
#endif
        
        [_audioSampleLock unlock];
    }
    
    if(self.isRecording)
        [self.videoWriter processAudioBuffer:sampleBuffer];
}

- (void)dealVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if(self.sharedContext == nil || dispatch_semaphore_wait(_videoSampleSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return;
    }
    
    CFRetain(sampleBuffer);
    
    [self.sharedContext asyncProcessingQueue:^{
     
        [self.sharedContext makeCurrent];
        
        CVImageBufferRef imageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        CGE_FRAMERENDERER_VIDEOHANDLER_TYPE* videoHandler = (CGE_FRAMERENDERER_VIDEOHANDLER_TYPE*)[self getVideoHandler];

        if(videoHandler != nullptr && videoHandler->updateFrameWithCVImageBuffer(imageBufferRef))
        {
            const CGESizei& sz = videoHandler->getOutputFBOSize();

            if(_processingDelegate != nil)
            {
                BOOL shouldWriteBack = NO;
                
                if([_processingDelegate respondsToSelector:@selector(bufferRequestRGBA)] && [_processingDelegate bufferRequestRGBA])
                {
                    if(_cgeUtilTexture.framebuffer == 0 || sz.width != _cgeUtilTexture.textureWidth || sz.height != _cgeUtilTexture.textureHeight)
                    {
                        [self clearGLData];
                        
                        if(![self setupGLData:sz.width andHeight:sz.height])
                        {
                            CGE_LOG_ERROR("frame recorder setupGLData failed!\n");
                        }
                    }
                    
                    [_cgeUtilTexture bindTextureFramebuffer];
                    
                    videoHandler->drawResult();
                    glFinish();
                    
                    shouldWriteBack = [_processingDelegate processingHandleBuffer: _cgeUtilTexture.pixelBufferRef];
                }
                else
                {
                    shouldWriteBack = [_processingDelegate processingHandleBuffer:imageBufferRef];
                }
                
                [self.renderLock lock];
                
                if(_globalFilter != nullptr && _globalFilterIntensity != 0.0f)
                {
                    videoHandler->processingWithFilter(_globalFilter);
                }
                
                if(shouldWriteBack)
                {
                    auto* drawer = videoHandler->getResultDrawer();
                    videoHandler->setAsTarget();
                    drawer->drawTexture(_cgeUtilTexture.textureID);
                    glFinish();
                }
                
                CVOpenGLESTextureCacheFlush(_cgeUtilTexture.textureCacheRef, 0);
                
                if([_processingDelegate respondsToSelector:@selector(drawProcResults:)])
                {
                    videoHandler->setAsTarget();
                    [_processingDelegate drawProcResults:videoHandler];
                }
            }
            else
            {
                [self.renderLock lock];
                
                if(_globalFilter != nullptr && _globalFilterIntensity != 0.0f)
                {
                    videoHandler->processingWithFilter(_globalFilter);
                }
            }
            
            videoHandler->processingFilters();
            
            if(_extraRenderingDelegate != nil)
            {
                [_extraRenderingDelegate extraDrawFrame:videoHandler];
            }
            
            if(self.isRecording)
            {
                CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                [self.videoWriter processFrameWithTexture:videoHandler->getTargetTextureID() atTime:currentTime];
            }
            [self.renderLock unlock];
            [self.updateDelegate frameUpdated];
        }
        
        CFRelease(sampleBuffer);
        dispatch_semaphore_signal(_videoSampleSemaphore);
     }];
}

- (void)setPictureHighResolution:(BOOL)useHightResolution
{
    if([[_cameraDevice stillImageOutput] respondsToSelector:@selector(setHighResolutionStillImageOutputEnabled:)])
        [[_cameraDevice stillImageOutput] setHighResolutionStillImageOutputEnabled:useHightResolution];
}

- (void)takePicture :(void (^)(UIImage*))block filterConfig:(const char*)config filterIntensity:(float)intensity isFrontCameraMirrored:(BOOL)mirrored
{
    if([[_cameraDevice stillImageOutput] isCapturingStillImage])
    {
        CGE_NSLog(@"拍照速度过于频繁!!");
        block(nil);
        return;
    }

    [[_cameraDevice stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[_cameraDevice stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        if(imageDataSampleBuffer != nil)
        {
            
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage* image = [[UIImage alloc] initWithData:imageData];
            
            //处理前置摄像头镜像
            if(mirrored && [_cameraDevice cameraPosition] == AVCaptureDevicePositionFront)
            {
                image = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:UIImageOrientationRightMirrored];
            }
            
            UIImage* filterImage;
            if(config == nullptr || *config == '\0')
            {
                filterImage = cgeForceUIImageUp(image, -1);
            }
            else
            {
                filterImage = cgeFilterUIImage_MultipleEffects(image, config, intensity, self.sharedContext);
            }

            block(filterImage);
          }
    }];
}


- (void)setMaskTextureRatio:(float)aspectRatio
{
    _maskAspectRatio = aspectRatio;
    
    CGSize sz = [_cameraDevice cameraResolution];
    
    float dstRatio = sz.height / sz.width; //默认竖屏旋转
    float s = dstRatio / aspectRatio;
    
    [super setMaskTextureRatio:s];
}

- (void)setGlobalFilter:(const char *)config
{
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
        delete _globalFilter;
        _globalFilter = nullptr;
        
        if(config == nullptr || *config == '\0')
        {
            return ;
        }
        
        _globalFilterIntensity = 1.0f;
        CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
        filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
        if(!filter->initWithEffectString(config))
        {
            delete filter;
            filter = nullptr;
        }
        
        if(filter->isWrapper())
        {
            auto f = filter->getFilters();
            if(!f.empty())
                _globalFilter = f[0];
            delete filter;
        }
        else
        {
            _globalFilter = filter;
        }
    }];
}

- (void)setGlobalFilterIntensity:(float)intensity
{
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
        _globalFilterIntensity = intensity;
        
        if(_globalFilter != nullptr)
        {
            _globalFilter->setIntensity(intensity);
        }
        else
        {
            CGE_LOG_ERROR("You must set a tracking filter first!\n");
        }
    }];
}

- (float)globalFilterIntensity
{
    return _globalFilterIntensity;
}

- (BOOL)hasGlobalFilter
{
    return _globalFilter != nullptr;
}

@end













