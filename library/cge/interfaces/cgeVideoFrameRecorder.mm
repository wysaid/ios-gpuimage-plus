/*
 * cgeVideoFrameRecorder.mm
 *
 *  Created on: 2015-10-10
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeVideoFrameRecorder.h"
#import "cgeVideoHandlerCV.h"
#import "cgeUtilFunctions.h"
#include "cgeBlendFilter.h"
#import <GLKit/GLKit.h>

#ifndef _CGE_ONLY_FILTERS_

#include "cgeAnimationParser.h"
#include "cgeSlideshow.h"

#else

#include "cgeVec.h"

#endif

using namespace CGE;

static double s_fpsLimit = 40.0;  //避免超高帧率视频等待时间过长
static int s_fpsCount;

@interface CGEVideoFrameRecorder()
{
    AVAsset* _videoAsset;
    NSURL* _videoURL;

    CMTime _prevFrameTime, _procFrameTime;
    CFAbsoluteTime _prevActualFrameTime;
    
#ifndef _CGE_ONLY_FILTERS_
    
    TimeLine* _timeline;
    
#endif

    __unsafe_unretained AVAssetReaderOutput* _readerVideoTrackOutput;
    __unsafe_unretained AVAssetReaderOutput* _readerAudioTrackOutput;
    
    CGELerpBlurUtil* _lerpBlur;
    Vec4i _clipViewport, _fitViewport;
    CGETextureInfo _cacheTexture; //A small texture for blur cache.
    CGETextureInfo _resultTexture;
    TextureDrawer* _drawer;
}

@end

@implementation CGEVideoFrameRecorder

- (id)initWithContext:(CGESharedGLContext *)sharedContext
{
    self = [super initWithContext:sharedContext];
    _mute = NO;
    
#ifndef _CGE_ONLY_FILTERS_
    
    _timeline = nullptr;
    
#endif
    
    return self;
}

- (void)dealloc
{
    [self clear];
}

- (void)clear
{
    _videoFrameRecorderDelegate = nil;

    if(_videoAssetReader)
        [self end];

    _videoAsset = nil;
    _videoURL = nil;
    
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
#ifndef _CGE_ONLY_FILTERS_
        
        if(_timeline != nullptr)
        {
            delete _timeline;
            _timeline = nullptr;
        }
        
#endif
        
        if(_lerpBlur != nullptr)
        {
            delete _lerpBlur;
            _lerpBlur = nullptr;
        }
        
        if(_cacheTexture.name != 0)
        {
            glDeleteTextures(1, &_cacheTexture.name);
            _cacheTexture.name = 0;
        }
        
        if(_resultTexture.name != 0)
        {
            glDeleteTextures(1, &_resultTexture.name);
            _resultTexture.name = 0;
        }
        
    }];
    
    [super clear];
}

- (void)setupWithAsset:(AVAsset *)asset completionHandler:(void (^)(BOOL))block
{
    _videoAsset = asset;
    _videoURL = nil;
    
    if(_videoAsset)
    {
        AVAssetTrack* track = [[_videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

        [track loadValuesAsynchronouslyForKeys:@[@"preferredTransform"] completionHandler:^{

            NSError* err;
            if ([track statusOfValueForKey:@"preferredTransform" error:&err] == AVKeyValueStatusLoaded)
            {
                //解决 video 旋转问题 2015-12-3

                CGAffineTransform preferredTransform = [track preferredTransform];

                /*
                 The orientation of the camera while recording affects the orientation of the images received from an AVPlayerItemVideoOutput. Here we compute a rotation that is used to correctly orientate the video.
                 */
                double rotation = atan2(preferredTransform.b, preferredTransform.a);
                CGE_NSLog(@"The video preferred rotation: %g", rotation);

                [self.sharedContext syncProcessingQueue:^{
                    [self.sharedContext makeCurrent];

                    CGE_FRAMERENDERER_VIDEOHANDLER_TYPE* videoHandler = (CGE_FRAMERENDERER_VIDEOHANDLER_TYPE*)[self getVideoHandler];

                    if(videoHandler != nullptr)
                    {
                        auto drawer = videoHandler->getYUVDrawer();
                        drawer->setRotation(rotation);

                        if(fabs(sin(rotation)) > 0.1) // 需要交换宽高
                        {
                            [self setReverseTargetSize:YES];
                        }
                        else
                        {
                            [self setReverseTargetSize:NO];
                        }

                        videoHandler->setReverseTargetSize(self.reverseTargetSize);
                    }
                }];

                _videoResolution = [track naturalSize];

                if(self.reverseTargetSize)
                {
                    _videoResolution = CGSizeMake(_videoResolution.height, _videoResolution.width);
                }

//                if(_timeline != nullptr)
//                {
//                    cgeInitialize(_videoResolution.width, _videoResolution.height, CGEGlobalConfig::CGE_INIT_DEFAULT);
//                }
                
                if([_videoFrameRecorderDelegate respondsToSelector:@selector(videoResolutionChanged:)])
                {
                    [_videoFrameRecorderDelegate videoResolutionChanged:_videoResolution];
                }

                if(block)
                    block(YES);
            }
            else
            {
                CGE_NSLog(@"Get video transform failed: %@", err);
                if(block)
                    block(NO);
            }
        }];

    }
    else
    {
        if(block)
            block(NO);
    }
}

- (void)setupWithURL:(NSURL *)url completionHandler:(void (^)(BOOL))block
{
    _videoURL = url;
    _videoAsset = nil;

    [self startWithURL:block];
}

- (void)setVideoOrientation:(int)videoOrientation
{
    _videoOrientation = videoOrientation;
    
    [self.sharedContext syncProcessingQueue:^{
        
        [self.sharedContext makeCurrent];
        
        if(_drawer == nullptr)
            _drawer = TextureDrawer::create();
        
        _drawer->setRotation(M_PI_2 * _videoOrientation);
        
        CGE_DELETE_GL_OBJS(glDeleteTextures, _cacheTexture.name, _resultTexture.name);
    }];
}

- (Vec4i)calcViewport:(int)viewWidth viewHeight:(int)viewHeight videoRatio:(float)videoRatio inner:(BOOL)inner
{
    float w, h;
    
    if(inner)
    {
        w = (int)roundf(viewHeight * videoRatio);
        h = viewHeight;
    }
    else
    {
        w = viewWidth;
        h = (int)roundf(viewWidth / videoRatio);
    }
    
    Vec4i viewport;
    
    viewport[0] = (viewWidth - w) / 2;
    viewport[1] = (viewHeight - h) / 2;
    viewport[2] = w;
    viewport[3] = h;
    return viewport;
}

- (void)processVideoFrame:(CVPixelBufferRef)imageBufferRef sampleTime:(CMTime)sampleTime lastTime:(CMTime)lastTime
{
    [self.sharedContext syncProcessingQueue:^{

        [self.sharedContext makeCurrent];

        CGE_FRAMERENDERER_VIDEOHANDLER_TYPE* videoHandler = (CGE_FRAMERENDERER_VIDEOHANDLER_TYPE*)[self getVideoHandler];

        if(videoHandler != nullptr && videoHandler->updateFrameWithCVImageBuffer(imageBufferRef))
        {
            [self.renderLock lock];
            videoHandler->processingFilters();
            
#ifndef _CGE_ONLY_FILTERS_
            
            if(_timeline != nullptr)
            {
                glEnable(GL_BLEND);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                
                float during = (CMTimeGetSeconds(sampleTime) - CMTimeGetSeconds(lastTime)) * 1000.0f;
//                CGE_LOG_INFO("timeline during: %g\n", during);
                _timeline->update(during);
                
                //viewport 在 processing或者 updateFrameWithCVImageBuffer 之后已经设置正确
                _timeline->render();
                glFinish();
            }
            
#endif
            
            if(self.isRecording)
            {
                bool shouldReverse = (_videoOrientation % 2) != 0;
                
                if(_enableBackgroundBlurring)
                {
                    if(_lerpBlur == nullptr || _cacheTexture.name == 0 || _resultTexture.name == 0)
                    {
                        if(_cacheTexture.name != 0 || _resultTexture.name != 0)
                            CGE_DELETE_GL_OBJS(glDeleteTextures, _cacheTexture.name, _resultTexture.name);
                        
                        _lerpBlur = CGELerpBlurUtil::create();
                        _cacheTexture.width = self.videoWriter.videoSize.width / 4;
                        _cacheTexture.height = self.videoWriter.videoSize.height / 4;
                        _cacheTexture.name = cgeGenTextureWithBuffer(nullptr, _cacheTexture.width, _cacheTexture.height, GL_RGBA, GL_UNSIGNED_BYTE);
                        
                        _resultTexture.width = self.videoWriter.videoSize.width;
                        _resultTexture.height = self.videoWriter.videoSize.height;
                        _resultTexture.name = cgeGenTextureWithBuffer(nullptr, _resultTexture.width, _resultTexture.height, GL_RGBA, GL_UNSIGNED_BYTE);
                        
                        if(_drawer == nullptr)
                            _drawer = TextureDrawer::create();
                        
                        int viewWidth1 = _cacheTexture.width, viewHeight1 = _cacheTexture.height;
                        int viewWidth2 = _resultTexture.width, viewHeight2 = _resultTexture.height;
                        
//                        if(shouldReverse)
//                        {
//                            std::swap(viewWidth1, viewHeight1);
//                            std::swap(viewWidth2, viewHeight2);
//                        }
                        
                        float videoRatio = shouldReverse ? _videoResolution.height / _videoResolution.width : _videoResolution.width / _videoResolution.height;
                        float viewRatio = viewWidth1 / (float)viewHeight1;
                        float s = videoRatio / viewRatio;
                        
                        _clipViewport = [self calcViewport:viewWidth1 viewHeight:viewHeight1 videoRatio:videoRatio inner:(s > 1.0f)];
                        
                        viewRatio = viewWidth2 / (float)viewHeight2;
                        s = viewRatio / viewRatio;
                        
                        _fitViewport = [self calcViewport:viewWidth2 viewHeight:viewHeight2 videoRatio:videoRatio inner:(s < 1.0f)];
                        
//                        if(shouldReverse)
//                        {
//                            std::swap(_clipViewport[0], _clipViewport[1]);
//                            std::swap(_clipViewport[2], _clipViewport[3]);
//                            std::swap(_fitViewport[0], _fitViewport[1]);
//                            std::swap(_fitViewport[2], _fitViewport[3]);
//                        }
                        
                        if(_clipViewport[0] == 0 && _clipViewport[1] == 0)
                        {
                            CGE_NSLog(@"It's a full screen video, skipping calc background blurring!");
                        }
                        
                        if(_lerpBlur == nullptr || _cacheTexture.name == 0 || _drawer == nullptr || (_clipViewport[0] == 0 && _clipViewport[1] == 0 && _videoOrientation == 0))
                        {
                            CGE_NSLog(@"No rotation, Disable background blurring!");
                            
                            delete _lerpBlur;
                            _lerpBlur = nullptr;
                            delete _drawer;
                            _drawer = nullptr;
                            glDeleteTextures(1, &_cacheTexture.name);
                            _cacheTexture.name = 0;
                            _enableBackgroundBlurring = NO;
                            [self.videoWriter processFrameWithTexture:videoHandler->getTargetTextureID() atTime:sampleTime];
                            [self.renderLock unlock];
                            return ;
                        }
                        else
                        {
                            _lerpBlur->setBlurLevel(7);
                        }
                    }
                    
                    if(_clipViewport[0] != 0 || _clipViewport[1] != 0)
                    {
                        auto& fb = _lerpBlur->frameBuffer();
                        fb.bindTexture2D(_cacheTexture.name);
                        glViewport(_clipViewport[0], _clipViewport[1], _clipViewport[2], _clipViewport[3]);
                        _drawer->drawTexture(videoHandler->getTargetTextureID());
                        glFlush();
                        
                        _lerpBlur->calcWithTexture(_cacheTexture.name, _cacheTexture.width, _cacheTexture.height);
                        fb.bindTexture2D(_resultTexture.name, _resultTexture.width, _resultTexture.height);
                        _lerpBlur->drawTexture(_lerpBlur->getResult());
                        
                        glViewport(_fitViewport[0], _fitViewport[1], _fitViewport[2], _fitViewport[3]);
                        _drawer->drawTexture(videoHandler->getTargetTextureID());
                        glFlush();
                        [self.videoWriter processFrameWithTexture:_resultTexture.name atTime:sampleTime];
                    }
                    else
                    {
                        auto& fb = _lerpBlur->frameBuffer();
                        fb.bindTexture2D(_resultTexture.name);
                        glViewport(0, 0, _resultTexture.width, _resultTexture.height);
                        _drawer->drawTexture(videoHandler->getTargetTextureID());
                        glFlush();
                        [self.videoWriter processFrameWithTexture:_resultTexture.name atTime:sampleTime];
                    }
                }
                else
                {
                    [self.videoWriter processFrameWithTexture:videoHandler->getTargetTextureID() atTime:sampleTime];
                }
            }

            [self.renderLock unlock];
            
            if(self.updateDelegate)
                [self.updateDelegate frameUpdated];
        }
    }];
}

- (AVAssetReader*)createAssetReader
{
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:_videoAsset error:&error];
    
    if(CMTimeGetSeconds(_timeRange.duration) > 0.1)
    {
        [assetReader setTimeRange:_timeRange];
    }
    
    NSDictionary *outputSettings = @{
                                     (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                                     };

//    [outputSettings setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    // Maybe set alwaysCopiesSampleData to NO on iOS 5.0 for faster video decoding
    NSArray<AVAssetTrack*>* videoTracks = [_videoAsset tracksWithMediaType:AVMediaTypeVideo];
    if(videoTracks != nil && videoTracks.count != 0)
    {
        AVAssetReaderTrackOutput *readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTracks[0] outputSettings:outputSettings];
        readerVideoTrackOutput.alwaysCopiesSampleData = NO;
        if([assetReader canAddOutput:readerVideoTrackOutput])
            [assetReader addOutput:readerVideoTrackOutput];
    }

    //////////////
    
    if(!_mute)
    {
        NSArray *audioTracks = [_videoAsset tracksWithMediaType:AVMediaTypeAudio];
        BOOL shouldRecordAudioTrack = ([audioTracks count] > 0);
        AVAssetReaderTrackOutput *readerAudioTrackOutput = nil;
        
        if (shouldRecordAudioTrack)
        {
            // This might need to be extended to handle movies with more than one audio track
            AVAssetTrack* audioTrack = [audioTracks objectAtIndex:0];
            
            if(audioTrack != nil)
            {
                if(self.shouldPassthroughAudio)
                {
                    readerAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
                    readerAudioTrackOutput.alwaysCopiesSampleData = NO;
                    [assetReader addOutput:readerAudioTrackOutput];
                }
                else
                {
                    NSDictionary* audioSettings = nil;
                    NSArray* formatDesc = [audioTrack formatDescriptions];
                    if(formatDesc.count != 0)
                    {
                        CMAudioFormatDescriptionRef descRef = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:0];
                        const AudioStreamBasicDescription* pcmAudioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(descRef);
                        
                        audioSettings = @{
                                          AVFormatIDKey : @(kAudioFormatLinearPCM),
                                          AVSampleRateKey : @(pcmAudioDesc->mSampleRate),
                                          AVNumberOfChannelsKey : @(pcmAudioDesc->mChannelsPerFrame),
                                          };
                        Float64 audioSampleRate = pcmAudioDesc->mSampleRate;
                        UInt32 audioChannelsPerFrame = pcmAudioDesc->mChannelsPerFrame;
                        CGE_NSLog(@"Audio sampe rate: %g, chennel per frame: %d\n", audioSampleRate, (int)audioChannelsPerFrame);
                    }
                    else
                    {
                        audioSettings = @{ AVFormatIDKey : @(kAudioFormatLinearPCM) };
                    }
                    
                    readerAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:audioSettings];
                    readerAudioTrackOutput.alwaysCopiesSampleData = NO;
                    
                    if([assetReader canAddOutput:readerAudioTrackOutput])
                        [assetReader addOutput:readerAudioTrackOutput];
                    else
                        readerAudioTrackOutput = nil;
                }
            }
        }
    }
    return assetReader;
}

- (void)startWithURL:(void (^)(BOOL))block
{
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:_videoURL options:inputOptions];
    
    if(!inputAsset)
    {
        if(block)
            block(NO);
        return;
    }
    
    __weak CGEVideoFrameRecorder *blockSelf = self;

    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler: ^{
        
        if(blockSelf == nil)
        {
            if(block)
                block(NO);
            return ;
        }
        
        NSError *error = nil;
        AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"tracks" error:&error];

        if (tracksStatus == AVKeyValueStatusLoaded)
        {
            [blockSelf setupWithAsset:inputAsset completionHandler:block];
        }
        else
        {
            if(block)
                block(NO);
        }
    }];

}

- (float)progress
{
    if(_videoAssetReader.status == AVAssetReaderStatusReading)
    {
        float current = _procFrameTime.value / (float)_procFrameTime.timescale;
        float duration = _videoAsset.duration.value / (float)_videoAsset.duration.timescale;
        return current / duration;
    }

    return _videoAssetReader.status == AVAssetReaderStatusCompleted ? 1.0f : 0.0f;
}

- (CMTime)duration
{
    return _videoAsset.duration;
}

- (void)startRunloop
{
    _prevFrameTime = kCMTimeZero;
    _prevActualFrameTime = CFAbsoluteTimeGetCurrent();
    
    _procFrameTime = kCMTimeZero;

    _videoAssetReader = [self createAssetReader];

    _readerVideoTrackOutput = nil;
    _readerAudioTrackOutput = nil;
    s_fpsCount = 0;

    for( AVAssetReaderOutput *output in _videoAssetReader.outputs )
    {
        if( [output.mediaType isEqualToString:AVMediaTypeAudio] )
        {
            _readerAudioTrackOutput = output;
        }
        else if( [output.mediaType isEqualToString:AVMediaTypeVideo] )
        {
            _readerVideoTrackOutput = output;
        }
    }

    if ([_videoAssetReader startReading] == NO)
    {
        CGE_LOG_ERROR("Reading video failed!\n");
        return;
    }
    
#ifndef _CGE_ONLY_FILTERS_
    
    if(_timeline != nullptr)
    {
        [self.sharedContext syncProcessingQueue:^{
            [self.sharedContext makeCurrent];
            _timeline->start();
        }];
    }
    
#endif

    _videoLoopRunning = YES;
    [self performSelectorInBackground:@selector(videoRunloop) withObject:nil];
    
    if(!_mute && _readerAudioTrackOutput)
    {
        _audioLoopRunning = YES;
        [self performSelectorInBackground:@selector(audioRunLoop) withObject:nil];
    }
    else
    {
        _audioLoopRunning = NO;
    }
}

- (void)videoRunloop
{
    CGE_NSLog(@"videoRunloop start...\n");
    while(_videoAssetReader.status == AVAssetReaderStatusReading)
    {
        if(_readerVideoTrackOutput == nil || self.videoWriter.assetWriter.status == AVAssetWriterStatusFailed)
            break;

        [self readNextVideoFrameFromOutput];
        CGE_LOG_INFO("Video Progress: %g \n", self.progress);
    }

    while(_audioLoopRunning)
    {
        [NSThread sleepForTimeInterval:0.02];
    }

    _videoLoopRunning = NO;
    CGE_NSLog(@"videoRunloop ended...\n");
    
    if(self.videoAssetReader.status == AVAssetReaderStatusCompleted && self.videoWriter.assetWriter.status != AVAssetWriterStatusFailed)
    {
        [self.videoFrameRecorderDelegate videoReadingComplete:self];
    }
    else
    {
        [self.videoFrameRecorderDelegate videoReadingComplete:nil];
    }
}

- (void)audioRunLoop
{
    CGE_NSLog(@"audioRunLoop start...\n");
    while(_videoAssetReader.status == AVAssetReaderStatusReading)
    {
        if(_readerAudioTrackOutput == nil || self.videoWriter.assetWriter.status == AVAssetWriterStatusFailed)
            break;

        [self readNextAudioSampleFromOutput];
    }

    if(!self.videoWriter.audioEncodingOver && self.videoWriter.assetWriter.status != AVAssetWriterStatusFailed)
    {
        [self.sharedContext syncProcessingQueue:^{
            [self.videoWriter.assetAudioInput markAsFinished];
            [self.videoWriter setAudioEncodingOver:YES];
        }];
    }
    
    _audioLoopRunning = NO;
    
    CGE_NSLog(@"audioRunLoop ended...\n");
}

- (BOOL)readNextVideoFrameFromOutput
{
    if(_readerVideoTrackOutput)
    {
        if(_videoAssetReader.status == AVAssetReaderStatusReading)
        {
            CMSampleBufferRef sampleBufferRef = [_readerVideoTrackOutput copyNextSampleBuffer];

            if(sampleBufferRef)
            {
                CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);

                if (_playAtActualSpeed)
                {
                    CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, _prevFrameTime);
                    CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();

                    CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
                    CGFloat actualTimeDifference = currentActualTime - _prevActualFrameTime;

                    if (frameTimeDifference > actualTimeDifference)
                    {
                        usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
                    }

                    _prevFrameTime = currentSampleTime;
                    _prevActualFrameTime = CFAbsoluteTimeGetCurrent();
                }

                if(s_fpsLimit > 0)
                {
                    double currTime = CMTimeGetSeconds(currentSampleTime);
                    int maxFrameForNow = currTime * s_fpsLimit + 5;
                    if(s_fpsCount > maxFrameForNow)
                    {
                        CGE_LOG_INFO("Too many frames, skip...");
                        CFRelease(sampleBufferRef);
                        return YES;
                    }
                    else
                    {
                        ++s_fpsCount;
                    }
                }
                
                CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(sampleBufferRef);
                [self processVideoFrame:movieFrame sampleTime:currentSampleTime lastTime:_procFrameTime];
                _procFrameTime = currentSampleTime;

                CFRelease(sampleBufferRef);
                return YES;
            }
            else
            {
                _readerVideoTrackOutput = nil;
            }
        }
    }

    return NO;
}

- (BOOL)readNextAudioSampleFromOutput
{
    if(_readerAudioTrackOutput)
    {
        if (_videoAssetReader.status == AVAssetReaderStatusReading)
        {
            CMSampleBufferRef audioSampleBufferRef = [_readerAudioTrackOutput copyNextSampleBuffer];
            if (audioSampleBufferRef)
            {
                if(self.isRecording)
                {
                    [self.videoWriter processAudioBuffer:audioSampleBufferRef];
                }

                CFRelease(audioSampleBufferRef);
                return YES;
            }
            else
            {
                _readerAudioTrackOutput = nil;
            }
        }

    }

    return NO;
}

- (void)setMaskTextureRatio:(float)aspectRatio
{
    if(_videoResolution.width < 1 || _videoResolution.height < 1)
    {
        [super setMaskTextureRatio:aspectRatio];
    }
    else
    {
        float dstRatio = _videoResolution.width / _videoResolution.height;
        float s = dstRatio / aspectRatio;
        [super setMaskTextureRatio:s];
    }
}

- (void)end
{
    _readerAudioTrackOutput = nil;
    _readerVideoTrackOutput = nil;

    if(self.videoWriter)
    {
        [self cancelRecording];
    }

    while(_videoLoopRunning)
    {
        [NSThread sleepForTimeInterval:0.02];
    }

    CGE_LOG_INFO("Video play ended.\n");

    if(_videoAssetReader)
    {
        if(_videoAssetReader.status == AVAssetReaderStatusReading)
        {
            [_videoAssetReader cancelReading];
        }

        _videoAssetReader = nil;
    }
}

- (void)start
{
    CGE_LOG_INFO("start to play...\n");

    if(_videoAsset)
    {
        [self startRunloop];
        return;
    }

//    if(_videoURL)
//    {
//        [self startWithURL];
//        return;
//    }

    CGE_LOG_ERROR("Error: The player should be setup before start!!!");
}

- (void)startRecording:(NSURL *)videoURL
{
    [self startRecording:videoURL size: _videoResolution];
}

- (void)startRecording:(NSURL *)videoURL size:(CGSize)videoSize outputSetting:(NSDictionary *)outputSetting
{
    if(outputSetting == nil)
    {
        outputSetting = @{@"EncodingLiveVideo":@NO};
    }
    else
    {
        NSMutableDictionary* tmpDic;
        if([outputSetting isKindOfClass:NSMutableDictionary.class])
        {
            tmpDic = (id)outputSetting;
        }
        else
        {
            tmpDic = [outputSetting mutableCopy];
        }
        
        [tmpDic setObject:@NO forKey:@"EncodingLiveVideo"];
        outputSetting = tmpDic;
    }

//    [super setShouldPassthroughAudio:YES];
    [super startRecording:videoURL size:videoSize outputSetting:outputSetting];
}

//- (void)endRecording :(void (^)(void))completionHandler withCompressionLevel:(int)level
//{
//    if(self.isRecording)
//    {
//        [super endRecording:completionHandler withCompressionLevel:level];
//    }
//
//}

- (void)setTimeline:(void *)timeline
{
#ifndef _CGE_ONLY_FILTERS_
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
        if(_timeline != timeline && _timeline != nullptr)
        {
            delete _timeline;
        }
        
        _timeline = (CGE::TimeLine*)timeline;
    }];
    
#else
    
    CGE_NSLog(@"timeline not supported by now.");
    
#endif
}

////////////////////////////////////

+ (double)fpsLimit
{
    return s_fpsLimit;
}

+ (void)setFPSLimit:(double)fps
{
    s_fpsLimit = fps;
}

+ (instancetype)generateVideoWithFilter:(NSURL *)ouputVideoUrl size:(CGSize)videoSize withDelegate:(id<CGEVideoFrameRecorderDelegate>)delegate videoConfig:(NSDictionary *)videoConfig
{
    return [CGEVideoFrameRecorder generateVideoWithFilter:ouputVideoUrl size:videoSize withDelegate:delegate videoConfig:videoConfig outputSetting:nil];
}

+ (instancetype)generateVideoWithFilter:(NSURL *)ouputVideoUrl size:(CGSize)videoSize withDelegate:(id<CGEVideoFrameRecorderDelegate>)delegate videoConfig:(NSDictionary *)videoConfig outputSetting:(NSDictionary*)outputSetting
{
    AVAsset* sourceAsset = [videoConfig objectForKey:@"sourceAsset"];
    NSURL* sourceURL;
    
    if(sourceAsset == nil)
    {
        sourceURL = [videoConfig objectForKey:@"sourceURL"];
    }
    
    if(!(sourceURL || sourceAsset))
        return nil;
    
    NSString* filterConfig = [videoConfig objectForKey:@"filterConfig"];
    
    id _filterIntensity = [videoConfig objectForKey:@"filterIntensity"];
    float filterIntensity = _filterIntensity ? [[videoConfig objectForKey:@"filterIntensity"] floatValue] : 1.0;
    
    UIImage* blendImage = [videoConfig objectForKey:@"blendImage"];
    id _blendMode = [videoConfig objectForKey:@"blendMode"];
    CGETextureBlendMode blendMode = _blendMode ? (CGETextureBlendMode)[_blendMode longValue] : CGE_BLEND_MIX;
    id _blendIntensity = [videoConfig objectForKey:@"blendIntensity"];
    float blendIntensity = _blendIntensity ?  [_blendIntensity floatValue] : 1.0f;
    
    CGEVideoFrameRecorder* videoFrameRecorder = [[CGEVideoFrameRecorder alloc] initWithContext:[CGESharedGLContext globalGLContext]];

    if(!videoFrameRecorder)
        return nil;
    
    BOOL mute = NO;
    
    id _mute = [videoConfig objectForKey:@"mute"];
    if(_mute)
    {
        mute = [_mute boolValue];
        [videoFrameRecorder setMute:mute];
    }
    
    [videoFrameRecorder setVideoFrameRecorderDelegate:delegate];
    
    if(filterConfig && filterConfig.length != 0 && filterIntensity != 0.0f)
    {
        [videoFrameRecorder setFilterWithConfig:[filterConfig UTF8String]];
        
        if(_filterIntensity)
            [videoFrameRecorder setFilterIntensity:filterIntensity];
    }
    
    if(blendImage)
    {
        [videoFrameRecorder.sharedContext syncProcessingQueue:^{
            
            [videoFrameRecorder.sharedContext makeCurrent];
            CGEBlendFilter* blendFilter = new CGEBlendFilter();
            
            GLuint texID = cgeCGImage2Texture(blendImage.CGImage, nullptr);
            
            if(texID != 0 && blendFilter->initWithMode(blendMode))
            {
                blendFilter->setSamplerID(texID);
                CGE_FRAMERENDERER_VIDEOHANDLER_TYPE* videoHandler = (CGE_FRAMERENDERER_VIDEOHANDLER_TYPE*)[videoFrameRecorder getVideoHandler];
                videoHandler->addImageFilter(blendFilter);
                blendFilter->setIntensity(blendIntensity);
            }
            else
            {
                delete blendFilter;
                if(texID != 0)
                    glDeleteTextures(1, &texID);
            }
            
        }];
    }

    dispatch_semaphore_t recSem = dispatch_semaphore_create(0);
    __block BOOL setupStatus = NO;

    id completionHandler = ^(BOOL status) {
        
        setupStatus = status;
        dispatch_semaphore_signal(recSem);
        
    };
    
    if(sourceAsset)
    {
        [videoFrameRecorder setupWithAsset:sourceAsset completionHandler:completionHandler];
    }
    else
    {
        [videoFrameRecorder setupWithURL:sourceURL completionHandler:completionHandler];
    }

    dispatch_semaphore_wait(recSem, DISPATCH_TIME_FOREVER);

    if(!setupStatus)
    {
        CGE_NSLog(@"setupAssetFailed!");
        [videoFrameRecorder clear];
        return nil;
    }
    
#ifndef _CGE_ONLY_FILTERS_
    
    id slideshow = [videoConfig objectForKey:@"slideshow"];
    
    if(slideshow)
    {
        [CGESharedGLContext globalSyncProcessingQueue:^{
            [CGESharedGLContext useGlobalGLContext];
#if _CGE_USE_GLOBAL_GL_CACHE_
            if(CGEGlobalConfig::sVertexBufferCommon == 0)
            {
                cgeInitialize(videoFrameRecorder.videoResolution.width, videoFrameRecorder.videoResolution.height, CGEGlobalConfig::CGE_INIT_DEFAULT);
            }
            else
#endif
            {
                cgeSetGlobalViewSize(videoFrameRecorder.videoResolution.width, videoFrameRecorder.videoResolution.height);
            }
            
            TimeLine* timeline = (TimeLine*)createSlideshowByConfig(slideshow, CMTimeGetSeconds(videoFrameRecorder.duration) * 1000.0f);
            [videoFrameRecorder setTimeline:timeline];
        }];
    }
    
#endif

    if(mute)
    {
        if(outputSetting == nil)
        {
            outputSetting = @{@"mute" : @(YES)};
        }
        else
        {
            NSMutableDictionary* dict;
            if([outputSetting isKindOfClass:NSMutableDictionary.class])
                dict = (id)outputSetting;
            else dict = [[NSMutableDictionary alloc] init];
            [dict setObject:@(YES) forKey:@"mute"];
            outputSetting = dict;
        }
    }
    
    NSArray* timeRange = [videoConfig objectForKey:@"timeRange"];
    if(timeRange && timeRange.count >= 2)
    {
        double start = [timeRange[0] doubleValue];
        double during = [timeRange[1] doubleValue];
        CMTimeRange range = CMTimeRangeMake(CMTimeMakeWithSeconds(start, 1000), CMTimeMakeWithSeconds(during, 1000));
        [videoFrameRecorder setTimeRange:range];
    }
    
    id _blur = [videoConfig objectForKey:@"blurBackground"];
    BOOL enableBlurring = _blur && [_blur boolValue];
    [videoFrameRecorder setEnableBackgroundBlurring:enableBlurring];
    
    id _videoOrientation = [videoConfig objectForKey:@"videoOrientation"];
    if(_videoOrientation)
    {
        int rot = [_videoOrientation intValue];
        [videoFrameRecorder setVideoOrientation:rot];
    }
    
    if(videoSize.width <= 0.0 || videoSize.height <= 0.0)
    {
        videoSize = videoFrameRecorder.videoResolution;
    }
    
    [videoFrameRecorder startRecording:ouputVideoUrl size:videoSize outputSetting: outputSetting];
    [videoFrameRecorder start];

    return videoFrameRecorder;
}

@end





