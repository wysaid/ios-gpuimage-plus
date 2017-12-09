/*
 * cgeVideoWriter.mm
 *
 *  Created on: 2015-9-14
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeVideoWriter.h"
#import "cgeSharedGLContext.h"
#import "cgeTextureUtils.h"
#import <UIKit/UIKit.h>
#import "cgeUtilFunctions.h"

using namespace CGE;

static CGEConstString s_fshVideoWriter = CGE_SHADER_STRING_PRECISION_M
(
varying vec2 texCoord;
uniform sampler2D inputImageTexture;
void main()
{
    gl_FragColor = texture2D(inputImageTexture, texCoord);
});

class VideoFrameDrawer : public TextureDrawer
{
public:
    CGE_COMMON_CREATE_FUNC(VideoFrameDrawer, init);
    
private:
    CGEConstString getFragmentShaderString()
    {
        return s_fshVideoWriter;
    }
};

/////////////////////////////////////////////

@interface CGEVideoWriter()
{
    CMTime _previousFrameTime, _previousAudioTime;
    
    GLuint _videoFramebuffer;//, videoRenderbuffer;
    
    BOOL _shouldValidateStart;
    
    BOOL _recordingOver;
    
    VideoFrameDrawer* _frameDrawer;
}

@property CGESharedGLContext* sharedContext;
@property(nonatomic, assign) CGRect cropArea;

/////////////////////////////////////////////

- (void)setupGLData;
- (void)clearGLData;
- (void)useDataFBO;

@end

@implementation CGEVideoWriter

- (void)dealloc
{
    [self clear];
    CGE_NSLog(@"### CGEVideoWriter Dealloc...\n");
}

- (void)clear
{
    if(_sharedContext != nil)
    {
        if(_isRecording)
        {
            [self cancelRecording];
            _isRecording = false;
        }
        [self clearGLData];
        _sharedContext = nil;
    }
}

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize
{
    return [self initWithMovieURL:newMovieURL size:newSize fileType:AVFileTypeMPEG4 outputSettings:nil];
}

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize fileType:(NSString *)newFileType outputSettings:(NSDictionary *)outputSettings
{
    return [self initWithMovieURL:newMovieURL size:newSize fileType:newFileType outputSettings:outputSettings usingContext:nil];
}

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize fileType:(NSString *)newFileType outputSettings:(NSDictionary *)outputSettings usingContext:(CGESharedGLContext*)context
{
    if(!(self = [super init]))
    {
        return nil;
    }

    _cropArea = CGRectMake(0.0, 0.0, 1.0, 1.0);
    _isRecording = NO;
    _videoEncodingOver = NO;
    _audioEncodingOver = NO;
    _videoSize = newSize;
    _fileType = newFileType;
    _fileURL = newMovieURL;
    _shouldValidateStart = YES;
    
    _encodingLiveVideo = [[outputSettings objectForKey:@"EncodingLiveVideo"] isKindOfClass:[NSNumber class]] ? [[outputSettings objectForKey:@"EncodingLiveVideo"] boolValue] : YES;
    _previousFrameTime = kCMTimeNegativeInfinity;
    _previousAudioTime = kCMTimeNegativeInfinity;

    _sharedContext = context == nil ? [CGESharedGLContext createGlobalSharedContext] : context;

    if([outputSettings objectForKey:@"EncodingLiveVideo"])
    {
        if([outputSettings count] == 1)
        {
            outputSettings = nil;
        }
        else
        {
            NSMutableDictionary *tmp = [outputSettings mutableCopy];
            [tmp removeObjectForKey:@"EncodingLiveVideo"];
            outputSettings = tmp;
        }
    }

    [self initializeMovieWithOutputSettings:outputSettings];
    
    return self;
}

- (void)initializeMovieWithOutputSettings:(NSDictionary *)outputSettings;
{
    _isRecording = NO;
    
    NSError *error = nil;
    _assetWriter = [[AVAssetWriter alloc] initWithURL:_fileURL fileType:_fileType error:&error];
    [_assetWriter setShouldOptimizeForNetworkUse:YES];
    
    CGE_NSAssert(error == nil, @"initializeMovieWithOutputSettings error: %@", error);
    
//    [_assetWriter setShouldOptimizeForNetworkUse:YES];
    
    if([_fileType isEqualToString:AVFileTypeQuickTimeMovie])
    {
        // Set this to make sure that a functional movie is produced, even if the recording is cut off mid-stream. Only the last second should be lost in that case.
        _assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
    }
    else
    {
        //Mpeg4 会出现帧写入失败错误, ref: https://github.com/BradLarson/GPUImage/issues/1729
        _assetWriter.movieFragmentInterval = kCMTimeInvalid;
    }
    
    // use default output settings if none specified
    if (outputSettings == nil || [outputSettings count] == 0)
    {
//        NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
//        [settings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
//        [settings setObject:[NSNumber numberWithInt:_videoSize.width] forKey:AVVideoWidthKey];
//        [settings setObject:[NSNumber numberWithInt:_videoSize.height] forKey:AVVideoHeightKey];
        
        outputSettings = @{
                           AVVideoCodecKey : AVVideoCodecH264,
                           AVVideoWidthKey : @(_videoSize.width),
                           AVVideoHeightKey : @(_videoSize.height),
                           };
        
//        outputSettings = @{
//                           AVVideoCodecKey : AVVideoCodecH264,
//                           AVVideoWidthKey : @(_videoSize.width),
//                           AVVideoHeightKey : @(_videoSize.height),
//                           AVVideoCompressionPropertiesKey : @{
//                                   AVVideoAverageBitRateKey : @(1650000),
//                                   AVVideoExpectedSourceFrameRateKey : @(30),
//                                   AVVideoMaxKeyFrameIntervalKey : @(30),
//                                   AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
//                                   }
//                           };
    }
    // custom output settings specified
    else
    {
        NSString *videoCodec = [outputSettings objectForKey:AVVideoCodecKey];
        NSNumber *width = [outputSettings objectForKey:AVVideoWidthKey];
        NSNumber *height = [outputSettings objectForKey:AVVideoHeightKey];
        CGE_NSAssert(videoCodec, @"OutputSettings is missing required parameters.");
        if(videoCodec == nil)
        {
            CGE_LOG_ERROR("Invalid outputSetting!!");
            return;
        }
        
        if(width == nil || height == nil)
        {
            NSMutableDictionary* setting = nil;
            
            if([outputSettings isKindOfClass:NSMutableDictionary.class])
            {
                setting = (NSMutableDictionary*)outputSettings;
            }
            else
            {
                setting = [outputSettings mutableCopy];
            }
            
            if(width == nil)
                [setting setObject:@(_videoSize.width) forKey:AVVideoWidthKey];
            if(height == nil)
                [setting setObject:@(_videoSize.height) forKey:AVVideoHeightKey];
            
            outputSettings = setting;
        }
    }
    
    _assetVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    _assetVideoInput.expectsMediaDataInRealTime = YES;
    
    // Use BGRA for the video in order to get realtime encoding.
    NSDictionary *sourcePixelBufferAttributesDictionary = @
    {
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey : @(_videoSize.width),
        (id)kCVPixelBufferHeightKey : @(_videoSize.height)
    };
    
    _assetPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_assetVideoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    [_assetWriter addInput:_assetVideoInput];
}

- (void)setupGLData
{
    glActiveTexture(GL_TEXTURE1);
    glGenFramebuffers(1, &_videoFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _videoFramebuffer);
    
    
    // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
    
    CVReturn err;
    
    err = CVPixelBufferPoolCreatePixelBuffer (NULL, [_assetPixelBufferInput pixelBufferPool], &_pixelBufferRef);
    
    CGE_NSAssert(err == kCVReturnSuccess, @"CVPixelBufferPoolCreatePixelBuffer failed!\n");    
    
    /* AVAssetWriter will use BT.601 conversion matrix for RGB to YCbCr conversion
     * regardless of the kCVImageBufferYCbCrMatrixKey value.
     * Tagging the resulting video file as BT.601, is the best option right now.
     * Creating a proper BT.709 video is not possible at the moment.
     */
    CVBufferSetAttachment(_pixelBufferRef, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(_pixelBufferRef, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(_pixelBufferRef, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
    
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [_sharedContext context], NULL, &_textureCacheRef);
    
    CGE_NSAssert(err == kCVReturnSuccess, @"CVOpenGLESTextureCacheCreate failed!\n");
    
    err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, _textureCacheRef, _pixelBufferRef,
                                                  NULL, // texture attributes
                                                  GL_TEXTURE_2D,
                                                  GL_RGBA, // opengl format
                                                  (int)_videoSize.width,
                                                  (int)_videoSize.height,
                                                  GL_BGRA, // native iOS format
                                                  GL_UNSIGNED_BYTE,
                                                  0,
                                                  &_textureRef);
    
    CGE_NSAssert(err == kCVReturnSuccess, @"CVOpenGLESTextureCacheCreateTextureFromImage failed!\n");
    
    glBindTexture(CVOpenGLESTextureGetTarget(_textureRef), CVOpenGLESTextureGetName(_textureRef));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(_textureRef), 0);
    
#ifdef DEBUG
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    CGE_NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %x\n", status);
    
#endif
    
    if(_frameDrawer == nullptr)
    {
        _frameDrawer = VideoFrameDrawer::create();
    }
}

- (void)clearGLData
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        if(_videoFramebuffer != 0)
        {
            glDeleteFramebuffers(1, &_videoFramebuffer);
            _videoFramebuffer = 0;
        }
        
        if(_textureCacheRef)
        {
            CFRelease(_textureCacheRef);
            _textureCacheRef = nil;
        }
        
        if(_textureRef != nil)
        {
            CFRelease(_textureRef);
            _textureRef = nil;
        }
        
        if(_pixelBufferRef != nil)
        {
            CVPixelBufferRelease(_pixelBufferRef);
            _pixelBufferRef = nil;
        }
        
        CVPixelBufferPoolRelease(_assetPixelBufferInput.pixelBufferPool);
        
        delete _frameDrawer;
        _frameDrawer = nullptr;
    }];
}

- (void)setCropArea:(CGRect)cropArea
{
    _cropArea.size.width = 1.0 / cropArea.size.width;
    _cropArea.size.height = 1.0 / cropArea.size.height;
    _cropArea.origin.x = -_cropArea.size.width * cropArea.origin.x;
    _cropArea.origin.y = -_cropArea.size.height * cropArea.origin.y;
}

- (void)useDataFBO
{
    if(_videoFramebuffer == 0)
    {
        [self setupGLData];
        glFinish();
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, _videoFramebuffer);
    glViewport(_videoSize.width * _cropArea.origin.x, _videoSize.height * _cropArea.origin.y, _videoSize.width * _cropArea.size.width, _videoSize.height * _cropArea.size.height);
}

- (void)doWritingVideoData :(CMTime)frameTime
{
    [_sharedContext makeCurrent];

    if(_assetVideoInput.readyForMoreMediaData && _assetWriter.status == AVAssetWriterStatusWriting)
    {
        if (![_assetPixelBufferInput appendPixelBuffer:_pixelBufferRef withPresentationTime:frameTime])
        {
            CGE_NSLog(@"Problem appending pixel buffer at time: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
        }
    }
    else
    {
        CGE_NSLog(@"Drop an video frame...\n");
    }
    
    _previousFrameTime = frameTime;
}

- (void)processFrameWithTexture :(GLuint)textureID atTime:(CMTime)frameTime
{
    if(!_isRecording)
        return;
    
    if(CMTIME_IS_INVALID(frameTime) || CMTIME_COMPARE_INLINE(frameTime, ==, _previousFrameTime))
    {
        return;
    }
    
    [_sharedContext syncProcessingQueue:^{
        
        if(_shouldValidateStart)
        {
            if([_assetWriter status] == AVAssetWriterStatusFailed)
            {
                CGE_LOG_ERROR("❌Can't record frame!\n");
                return ;
            }
                
            if([_assetWriter status] != AVAssetWriterStatusWriting)
            {
                [_assetWriter startWriting];
            }
            [_assetWriter startSessionAtSourceTime:frameTime];
            _shouldValidateStart = NO;
        }
        
        [_sharedContext makeCurrent];
        [self useDataFBO];
        glDisable(GL_BLEND);
        _frameDrawer->drawTexture(textureID);
        glFinish();

        if(!_encodingLiveVideo)
        {
            int waitLoopCount = 0;
            while (![_assetVideoInput isReadyForMoreMediaData] && _isRecording && !_videoEncodingOver && _assetWriter.status == AVAssetWriterStatusWriting)
            {
                [NSThread sleepForTimeInterval:0.02];

                if(++waitLoopCount > 100)  //Protect from crash.
                {
                    CGE_NSLog(@"❌Problem waiting for media data!");
                    return ;
                }
            }

            [self doWritingVideoData:frameTime];
        }
    }];

    if(_encodingLiveVideo)
    {
        [_sharedContext asyncProcessingQueue:^{
            [self doWritingVideoData:frameTime];
        }];
    }


}

- (void)setEncodingLiveVideo:(BOOL) value
{
    _encodingLiveVideo = value;
//    if (_isRecording)
//    {
//        CGE_NSAssert(NO, @"Can not change Encoding Live Video while recording");
//    }
//    else
//    {
//        _assetVideoInput.expectsMediaDataInRealTime = YES;
//        _assetAudioInput.expectsMediaDataInRealTime = YES;
//    }
}

- (void)setHasAudioTrack:(BOOL)hasAudioTrack
{
    [self setHasAudioTrack:hasAudioTrack audioSettings:nil];
}

- (void)setHasAudioTrack:(BOOL)hasAudioTrack audioSettings:(NSDictionary *)audioOutputSettings
{
    _hasAudioTrack = hasAudioTrack;
    
    if (_hasAudioTrack)
    {
        if (_shouldPassthroughAudio)
        {
            // Do not set any settings so audio will be the same as passthrough
            audioOutputSettings = nil;
        }
        else if (audioOutputSettings == nil)
        {
            double preferredHardwareSampleRate = [[AVAudioSession sharedInstance] sampleRate];
            AudioChannelLayout acl;
            bzero( &acl, sizeof(acl));
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
            
            audioOutputSettings = @
            {
                AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                AVNumberOfChannelsKey : @(1),
                AVSampleRateKey : @(preferredHardwareSampleRate),
                AVChannelLayoutKey : [NSData dataWithBytes: &acl length: sizeof(acl)],
                AVEncoderBitRateKey : @(128000),
//                AVEncoderAudioQualityKey : @(AVAudioQualityLow)
            };

        }
        
        _assetAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
        [_assetWriter addInput:_assetAudioInput];
        _assetAudioInput.expectsMediaDataInRealTime = YES;
    }
    else
    {
        _audioEncodingOver = true;
        // Remove audio track if it exists
    }
}

- (void)startRecording
{
    _recordingOver = NO;
    
    _shouldValidateStart = YES;
    _previousFrameTime = kCMTimeInvalid;
    _previousAudioTime = kCMTimeInvalid;
    
    [_sharedContext syncProcessingQueue: ^{
        
        [_assetWriter startWriting];
        
    }];

    
    _isRecording = YES;
}

- (void)startRecordingInOrientation:(CGAffineTransform)orientationTransform
{
    _assetVideoInput.transform = orientationTransform;
    [self startRecording];
}

- (void)finishRecording
{
    //强制线程同步， 等待 finishRecordingWithCompletionHandler 完成
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self finishRecordingWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)finishRecordingWithCompletionHandler:(void (^)(void))handler
{
    if(_assetWriter == nil)
    {
        CGE_NSLog(@"😨Warning: finishRecording before startRecording!!!\n");
        handler();
        return;
    }
    
    [_sharedContext syncProcessingQueue:^{
        _isRecording = NO;
        
        if (_assetWriter.status == AVAssetWriterStatusCompleted || _assetWriter.status == AVAssetWriterStatusCancelled || _assetWriter.status == AVAssetWriterStatusUnknown)
        {
            if (handler)
                [_sharedContext asyncProcessingQueue:handler];
            return;
        }
        
        if( _assetWriter.status == AVAssetWriterStatusWriting && ! _videoEncodingOver )
        {
            _videoEncodingOver = YES;
            [_assetVideoInput markAsFinished];
        }
        
        if( _assetWriter.status == AVAssetWriterStatusWriting && ! _audioEncodingOver )
        {
            _audioEncodingOver = YES;
            [_assetAudioInput markAsFinished];
        }
        
        [_assetWriter finishWritingWithCompletionHandler:^{
            _assetWriter = nil;
            handler();
        }];
    }];
}

- (void)cancelRecording
{
    if (_assetWriter.status == AVAssetWriterStatusCompleted)
    {
        return;
    }
    
    _isRecording = NO;
    [_sharedContext syncProcessingQueue :^{
        
        _recordingOver = YES;
        
        if( _assetWriter.status == AVAssetWriterStatusWriting && ! _videoEncodingOver )
        {
            _videoEncodingOver = YES;
            [_assetVideoInput markAsFinished];
        }
        if( _assetWriter.status == AVAssetWriterStatusWriting && ! _audioEncodingOver )
        {
            _audioEncodingOver = YES;
            [_assetAudioInput markAsFinished];
        }
        [_assetWriter cancelWriting];
    }];
}

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer
{
    if (!_isRecording || _shouldValidateStart)
    {
        int waitLoopCount = 0;

        while(_hasAudioTrack && _isRecording && _shouldValidateStart && !_encodingLiveVideo)
        {
//            [_sharedContext syncProcessingQueue:^{
//                CMTime startSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer);
//
//                if(_shouldValidateStart)
//                {
//                    if([_assetWriter status] != AVAssetWriterStatusWriting)
//                    {
//                        [_assetWriter startWriting];
//                    }
//                    [_assetWriter startSessionAtSourceTime:startSampleTime];
//                    _shouldValidateStart = NO;
//                }
//            }];

            [NSThread sleepForTimeInterval:0.02];

            if(++waitLoopCount > 100)  //Protect from crash.
            {
                CGE_NSLog(@"❌Problem waiting for validate status!");
                return ;
            }
        }

        if(_shouldValidateStart)
            return;
    }
    
    if (_hasAudioTrack)
    {
        CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer);
        
        if(_encodingLiveVideo && !_assetAudioInput.readyForMoreMediaData)
        {
            CGE_NSLog(@"😂 Drop an audio frame...\n");
            return;
        }

        if (!_encodingLiveVideo)
        {
            int waitLoopCount = 0;

            while(_isRecording && !_assetAudioInput.readyForMoreMediaData && !_audioEncodingOver && _assetWriter.status == AVAssetWriterStatusWriting)
            {
                [NSThread sleepForTimeInterval:0.02];

                if(++waitLoopCount > 100)  //Protect from crash.
                {
                    CGE_NSLog(@"❌Problem waiting for media data!");
                    return ;
                }
            }
        }

        CFRetain(audioBuffer);


        void(^write)() = ^() {

            _previousAudioTime = currentSampleTime;

            if(_assetAudioInput.readyForMoreMediaData && _assetWriter.status == AVAssetWriterStatusWriting)
            {
                if (![_assetAudioInput appendSampleBuffer:audioBuffer])
                {
                    CGE_NSLog(@"🙈Problem appending audio buffer");
                }
            }
            else
            {
                CGE_NSLog(@"😂Drop an audio frame...");
            }

            CFRelease(audioBuffer);
        };
        
        if( _encodingLiveVideo )
        {
            [_sharedContext asyncProcessingQueue: write];
        }
        else
        {
            write();
        }
    }
}

+ (void)compressVideo:(NSURL *)outputURL inputURL:(NSURL *)inputURL quality:(NSString *)quality shouldOptimizeForNetworkUse:(BOOL)shouldOptimize completionHandler:(void (^)(NSError *))handler
{
    if([[NSFileManager defaultManager] fileExistsAtPath:outputURL.path])
    {
        [[NSFileManager defaultManager] removeItemAtPath:outputURL.path error:nil];
    }
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:quality == nil ? AVAssetExportPresetPassthrough : quality];
    
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    
    if(shouldOptimize)
        exportSession.shouldOptimizeForNetworkUse = shouldOptimize;
    
    [exportSession exportAsynchronouslyWithCompletionHandler: ^(void) {
        
        if(handler)
        {
            handler(exportSession.status == AVAssetExportSessionStatusCompleted ? nil : exportSession.error);
            CGE_NSLog_Code
            (
             if(exportSession.status != AVAssetExportSessionStatusCompleted)
             CGE_NSLog(@"😂视频转码错误!\n");
             );
        }
    }];
}

+ (void)compressVideo:(NSURL *)outputURL inputURL:(NSURL *)inputURL quality:(NSString *)quality completionHandler:(void (^)(NSError *))handler
{
    [CGEVideoWriter compressVideo:outputURL inputURL:inputURL quality:quality shouldOptimizeForNetworkUse:YES completionHandler:handler];
}


+ (void)compressVideoWithLowQuality:(NSURL *)outputURL inputURL:(NSURL *)inputURL completionHandler:(void (^)(NSError *))handler
{
    [CGEVideoWriter compressVideo:outputURL inputURL:inputURL quality:AVAssetExportPresetLowQuality completionHandler:handler];
}

+ (void)compressVideoWithMediumQuality:(NSURL *)outputURL inputURL:(NSURL *)inputURL completionHandler:(void (^)(NSError *))handler
{
    [CGEVideoWriter compressVideo:outputURL inputURL:inputURL quality:AVAssetExportPresetMediumQuality completionHandler:handler];
}

+ (void)compressVideoWithHighQuality:(NSURL *)outputURL inputURL:(NSURL *)inputURL completionHandler:(void (^)(NSError *))handler
{
    [CGEVideoWriter compressVideo:outputURL inputURL:inputURL quality:AVAssetExportPresetHighestQuality completionHandler:handler];
}

+ (void)generateVideoWithImages:(NSURL *)outputVideoURL size:(CGSize)videoSize imgSrc:(NSArray *)imgArr imgRetrieveFunc:(UIImage *(^)(id))retrieveFunc audioURL:(NSURL *)audioURL quality:(NSString *)quality secPerFrame:(double)secPerFrame completionHandler:(void (^)(BOOL))block
{
    NSURL* cachedVideoURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"cgeCacheVideo_%d.mp4", rand()]]];

    if([[NSFileManager defaultManager] fileExistsAtPath:[cachedVideoURL path]])
    {
        [[NSFileManager defaultManager] removeItemAtPath:[cachedVideoURL path] error:nil];
    }

    if([[NSFileManager defaultManager] fileExistsAtPath:[outputVideoURL path]])
    {
        [[NSFileManager defaultManager] removeItemAtPath:[outputVideoURL path] error:nil];
    }

    NSError *error = nil;
    __block AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:cachedVideoURL fileType:AVFileTypeMPEG4 error:&error];
    
    if(error)
    {
        CGE_NSLog(@"Error creating AssetWriter: %@", [error description]);
        if(block)
            block(NO);
        return;
    }

    [videoWriter setShouldOptimizeForNetworkUse:YES];
    
    CGE_NSLog(@"正在生成视频， 视频分辨率: %g, %g", videoSize.width, videoSize.height);
    
    NSDictionary *videoSettings = @{
                                    AVVideoCodecKey : AVVideoCodecH264,
                                    AVVideoWidthKey : @(videoSize.width),
                                    AVVideoHeightKey : @(videoSize.height)
                                    };
    
    AVAssetWriterInput* writerInput = [AVAssetWriterInput
                                       assetWriterInputWithMediaType:AVMediaTypeVideo
                                       outputSettings:videoSettings];
    
    NSDictionary* attributes = @{
                                 (NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                 (NSString*)kCVPixelBufferWidthKey : @(videoSize.width),
                                 (NSString*)kCVPixelBufferHeightKey : @(videoSize.height)
                                 };

    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                     sourcePixelBufferAttributes:attributes];
    
    [videoWriter addInput:writerInput];
    
    // use 'readyForMoreMediaData' to judge the frame status.
    writerInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey: @(YES),
                              (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)};
    
    CVPixelBufferRef pixelBuffer = nil;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, videoSize.width, videoSize.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &pixelBuffer);
    
    if(status != kCVReturnSuccess || pixelBuffer == nil)
    {
        CGE_NSLog(@"生成视频失败!\n");
        if(block)
            block(NO);
        return;
    }
    
    BOOL startStatus = [videoWriter startWriting];
    int fps = int(1.0 / secPerFrame);
    
    if(startStatus)
    {
        [videoWriter startSessionAtSourceTime:kCMTimeZero];
        
        int frameIndex = 0;
        int bytesPerRow = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
        int width = (int)CVPixelBufferGetWidth(pixelBuffer);
        int height = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        for(id obj in imgArr)
        {
            while(!writerInput.readyForMoreMediaData)
            {
                [NSThread sleepForTimeInterval:0.02];
            }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, 0); //for both read&write
            
            void* pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
            
            if(pixelData == nil)
            {
                startStatus = NO;
                break;
            }
            
            CGContextRef ctx = CGBitmapContextCreate(pixelData, width, height, 8, bytesPerRow, cgeCGColorSpaceRGB(), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
            
            if(ctx == nil)
            {
                startStatus = NO;
                break;
            }
            
            UIImage* img = retrieveFunc ? retrieveFunc(obj) : obj;
            
            if(img == nil)
            {
                startStatus = NO;
                break;
            }

            CGE_NSLog_Code
            (
            CGE_NSLog(@"当前第 %d 帧, 图片尺寸: %g, %g\n", frameIndex, img.size.width, img.size.height);
            )
            
            CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), [img CGImage]);
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CGContextRelease(ctx);

            CMTime currentTime;

            if(fps <= 1)
                currentTime = CMTimeMakeWithSeconds(frameIndex++ * secPerFrame, 1);
            else
                currentTime = CMTimeMake(frameIndex++, fps);

            BOOL success = [adaptor appendPixelBuffer:pixelBuffer withPresentationTime:currentTime];

            if(!success)
            {
                CGE_NSLog(@"❗️Write frame %d failed!\n", frameIndex);
            }
        }
    }

    if(!startStatus)
    {
        CGE_NSLog(@"❌Error when generating video...\n");
        if(block)
            block(NO);
    }
    else
    {
        [writerInput markAsFinished];
        [videoWriter finishWritingWithCompletionHandler:^{
            videoWriter = nil;

            NSFileManager* fileManager = [NSFileManager defaultManager];

            if(audioURL)
            {
                CGE_NSLog(@"⭕️存在音频文件， 混合音频...\n");
                [CGEVideoWriter videoComposition:outputVideoURL inputVideoURL:@[cachedVideoURL] inputAudioURL:@[audioURL] keepVideoSound:NO quality:quality completionHandler:block];
            }
            else
            {
                CGE_NSLog(@"⭕️不存在音频文件， 压缩视频中...\n");

                [CGEVideoWriter compressVideo:outputVideoURL inputURL:cachedVideoURL quality:quality completionHandler:^(NSError *err) {

                    if(!err) //压缩成功
                    {
                        if(block)
                        {
                            block(err == nil);
                        }
                    }
                    else
                    {
                        NSError* err = nil;

                        if([fileManager fileExistsAtPath:[cachedVideoURL path]])
                        {
                            [fileManager moveItemAtPath:[cachedVideoURL path] toPath:[outputVideoURL path] error:&err];
                            if(err)
                            {
                                CGE_NSLog(@"Err: %@", err);
                            }
                        }

                        if(block)
                        {
                            block(err == nil);
                        }
                    }

                }];
            }
        }];
    }

    CVPixelBufferRelease(pixelBuffer);
    pixelBuffer = nil;
}

+ (void)videoComposition:(NSURL *)outputVideoURL inputVideoURL:(NSArray<NSURL *> *)inputVideoURLs inputAudioURL:(NSArray<NSURL *> *)inputAudioURLs keepVideoSound:(BOOL)keepVideoSound quality:(NSString *)quality completionHandler:(void (^)(BOOL))block
{
    if(inputVideoURLs == nil || inputVideoURLs.count == 0)
    {
        CGE_LOG_ERROR("Invalid Input!\n");
        return block(NO);
    }
    
    NSFileManager* fileManager = [NSFileManager defaultManager];

    BOOL(^rmURLs)(NSArray<NSURL*>* ) = ^(NSArray<NSURL*>* urls){
        
        if(urls != nil)
        {
            for(NSURL* url in inputVideoURLs)
            {
                if(![fileManager fileExistsAtPath:[url path]])
                {
                    return NO;
                }
            }
        }
        
        return YES;
    };
    
    if(!(rmURLs(inputVideoURLs) && rmURLs(inputAudioURLs)))
    {
        block(NO);
        return;
    }

    if ([fileManager fileExistsAtPath:[outputVideoURL path]])
        [fileManager removeItemAtPath:[outputVideoURL path] error:nil];

    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    CMTime videoTime = kCMTimeZero;
    
    {
        CMTime nextClipStartTime = kCMTimeZero;
        
        AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        AVMutableCompositionTrack *compositionAudioTrack = keepVideoSound ? [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid] : nil;
        
        for(NSURL* inputURL : inputVideoURLs)
        {
            AVAsset* videoAsset = [AVAsset assetWithURL:inputURL];
            NSArray<AVAssetTrack*>* videoTracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
            
            if(videoTracks == nil || videoTracks.count == 0)
            {
                block(NO);
                return;
            }
            
            AVAssetTrack* videoTrack = [videoTracks objectAtIndex:0];
            
            if(videoTrack)
            {
                CMTimeRange videoTimeRange = CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration);
                BOOL status = [compositionVideoTrack insertTimeRange:videoTimeRange ofTrack:videoTrack atTime:nextClipStartTime error:nil];
                
                if(status && compositionAudioTrack != nil)
                {
                    NSArray<AVAssetTrack*>* audioTrackArr = [videoAsset tracksWithMediaType:AVMediaTypeAudio];
                    if(audioTrackArr == nil)
                        continue;
                    for(AVAssetTrack* audioTrack in audioTrackArr)
                    {
                        if(audioTrack)
                        {
                            CMTimeRange audioTimeRange = CMTimeRangeMake(kCMTimeZero, audioTrack.timeRange.duration);
                            status = [compositionAudioTrack insertTimeRange:audioTimeRange ofTrack:audioTrack atTime:nextClipStartTime error:nil];
                        }
                    }
                    
                }
                
                if(!status)
                {
                    return block(NO);
                }
                
                nextClipStartTime = CMTimeAdd(nextClipStartTime, videoTimeRange.duration);
                
                CGE_NSLog(@"insert video: %g, next clip: %g", CMTimeGetSeconds(videoAsset.duration), CMTimeGetSeconds(nextClipStartTime));
            }
        }
        
        videoTime = nextClipStartTime;
    }
    

    if(inputAudioURLs != nil)
    {
        for(NSURL* inputURL in inputAudioURLs)
        {
            AVMutableCompositionTrack *mixAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            AVAsset* audioAsset = [AVAsset assetWithURL:inputURL];
            
            NSArray<AVAssetTrack*>* audioTrackArr = [audioAsset tracksWithMediaType:AVMediaTypeAudio];
            if(audioTrackArr == nil || audioTrackArr.count == 0)
                continue;
            
            for(AVAssetTrack* audioTrack in audioTrackArr)
            {
                if(audioTrack)
                {
                    CMTime audioTime = CMTimeMinimum(videoTime, audioTrack.timeRange.duration);
                    CMTimeRange audioTimeRange = CMTimeRangeMake(kCMTimeZero, audioTime);
                    
//                    if(CMTimeCompare(videoTime, audioTime) < 0)
//                    {
//                        CMTime subDuring = CMTimeSubtract(videoTime, nextClipStartTime);
//                        audioTimeRange = CMTimeRangeMake(kCMTimeZero, subDuring);
//                        CGE_NSLog(@"音频时间长度: %f s, 视频时间总长度: %f s, 当前音频时间长度: %f s, 音频时间裁剪长度: %f s", CMTimeGetSeconds(audioTime), CMTimeGetSeconds(videoTime), CMTimeGetSeconds(audioAsset.duration), CMTimeGetSeconds(subDuring));
//                        audioTime = videoTime;
//                    }
//                    else
//                    {
//                        audioTimeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);
//                    }
                    
                    BOOL status = [mixAudioTrack insertTimeRange:audioTimeRange ofTrack:audioTrack atTime:kCMTimeZero error:nil];
                    
                    if(!status)
                    {
                        return block(NO);
                    }
                }
            }
            
            
        }
        
    }

    AVAssetExportSession* assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:quality == nil ? AVAssetExportPresetPassthrough : quality];
    [assetExport setOutputFileType:AVFileTypeMPEG4];
    [assetExport setOutputURL:outputVideoURL];
    [assetExport setShouldOptimizeForNetworkUse:YES];

    [assetExport exportAsynchronouslyWithCompletionHandler:^{

        if(block)
        {
            block(assetExport.status == AVAssetExportSessionStatusCompleted);
        }
    }];
}

+ (void)remuxingVideoWithTimescale:(NSURL *)outputVideoURL inputURL:(NSURL *)inputURL timescale:(double)timescale quality:(NSString *)quality completionHandler:(void (^)(BOOL))block
{
    CGEAssert(block != nil); //block should not be nil!
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    if(![fileManager fileExistsAtPath:[inputURL path]] || timescale <= 0 || timescale == 1.0 || quality == nil || [quality isEqualToString:AVAssetExportPresetPassthrough])
    {
        CGE_NSLog(@"❌Invalid Argument Value!");
        block(NO);
        return;
    }
    
    if ([fileManager fileExistsAtPath:[outputVideoURL path]])
        [fileManager removeItemAtPath:[outputVideoURL path] error:nil];
    
    AVAsset *currentAsset = [AVAsset assetWithURL:inputURL];
    //scale video time range by timescale
    double videoScaleFactor = timescale;
    
    NSArray<AVAssetTrack*>* videoTracks = [currentAsset tracksWithMediaType:AVMediaTypeVideo];
    
    if(videoTracks == nil || videoTracks.count == 0)
    {
        block(NO);
        return;
    }
    
    AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];
    
    //create mutable composition
    AVMutableComposition *mixComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    NSError *videoInsertError = nil;
    BOOL videoInsertResult = [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration)
                                                            ofTrack:videoTrack
                                                             atTime:kCMTimeZero
                                                              error:&videoInsertError];
    if (!videoInsertResult || nil != videoInsertError)
    {
        CGE_NSLog(@"Insert video track failed!\n");
        block(NO);
        return;
    }
    
    [compositionVideoTrack scaleTimeRange:CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration)
                               toDuration:CMTimeMake(videoTrack.timeRange.duration.value*videoScaleFactor, videoTrack.timeRange.duration.timescale)];
    
    [compositionVideoTrack setPreferredTransform:videoTrack.preferredTransform];
    
    NSArray<AVAssetTrack*>* audioTracks = [currentAsset tracksWithMediaType:AVMediaTypeAudio];
    
    if(audioTracks != nil && audioTracks.count != 0)
    {
        for(AVAssetTrack* audioTrack in audioTracks)
        {
            AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            
            NSError *audioInsertError =nil;
            BOOL audioInsertResult =[compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioTrack.timeRange.duration)
                                                                   ofTrack:audioTrack
                                                                    atTime:kCMTimeZero
                                                                     error:&audioInsertError];
            
            if (!audioInsertResult || nil != audioInsertError) {
                [mixComposition removeTrack:compositionAudioTrack];
                continue;
            }
            
            [compositionAudioTrack scaleTimeRange:CMTimeRangeMake(kCMTimeZero, audioTrack.timeRange.duration)
                                       toDuration:CMTimeMake(audioTrack.timeRange.duration.value*videoScaleFactor, audioTrack.timeRange.duration.timescale)];
        }
        
    }
    
    AVAssetExportSession* assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:quality == nil ? AVAssetExportPresetPassthrough : quality];
    [assetExport setOutputURL:outputVideoURL];
    [assetExport setOutputFileType:AVFileTypeMPEG4];
    
    [assetExport setAudioTimePitchAlgorithm:AVAudioTimePitchAlgorithmVarispeed];
    [assetExport setShouldOptimizeForNetworkUse:YES];
    
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
         
         if(assetExport.status == AVAssetExportSessionStatusCompleted)
         {
             CGE_LOG_INFO("Generate Successful!\n");
             block(YES);
         }
         else
         {
             CGE_NSLog(@"Export session failed with error: %@", [assetExport error]);
             block(NO);
         }
     }];
    
}

+ (void)reverseVideo:(NSURL *)outputVideoURL inputURL:(NSURL *)inputURL completionHandler:(void (^)(BOOL))block
{
    CGEAssert(block != nil);
    
    {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        if(![fileManager fileExistsAtPath:[inputURL path]])
        {
            block(NO);
            return;
        }
        
        if ([fileManager fileExistsAtPath:[outputVideoURL path]])
            [fileManager removeItemAtPath:[outputVideoURL path] error:nil];
    }
    
    // Initialize the reader
    AVAsset* asset = [AVAsset assetWithURL:inputURL];
    NSError* error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] lastObject];
    
    if(!(reader && videoTrack))
    {
        return block(NO);
    }
    
    NSDictionary *readerOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange], kCVPixelBufferPixelFormatTypeKey, nil];
    AVAssetReaderTrackOutput* readerVideoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                        outputSettings:readerOutputSettings];
    readerVideoOutput.alwaysCopiesSampleData = NO;
    [reader addOutput:readerVideoOutput];
    
    AVAssetReaderTrackOutput* readerAudioOutput = nil;
    Float64 audioSampleRate = 44100;
    UInt32 audioChannelsPerFrame = 1;
    
    if(audioTrack != nil)
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
                              AVNumberOfChannelsKey : @(1),
                              };
            audioSampleRate = pcmAudioDesc->mSampleRate;
            audioChannelsPerFrame = pcmAudioDesc->mChannelsPerFrame;
        }
        else
        {
            audioSettings = @{ AVFormatIDKey : @(kAudioFormatLinearPCM) };
        }
        
        readerAudioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:audioSettings];
        readerAudioOutput.alwaysCopiesSampleData = NO;
        if([reader canAddOutput:readerAudioOutput])
            [reader addOutput:readerAudioOutput];
        else
            readerAudioOutput = nil;
    }
    
    [reader startReading];
    
    // read in the samples
    NSMutableArray *videoSamples = [[NSMutableArray alloc] init];
    
    CMSampleBufferRef tmpSample;
    
    while((tmpSample = [readerVideoOutput copyNextSampleBuffer]) != nil)
    {
        [videoSamples addObject:(__bridge id)tmpSample];
        CFRelease(tmpSample);
    }
    
    NSMutableArray *audioSamples = nil;
    std::vector<short> vecAudioData;
    
    if(readerAudioOutput != nil)
    {
        audioSamples = [[NSMutableArray alloc] init];
        while((tmpSample = [readerAudioOutput copyNextSampleBuffer]) != nil)
        {
//            AudioBufferList bufList;
//            CMBlockBufferRef blockBuffer = nil;
//            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(tmpSample, nil, &bufList, sizeof(bufList), nil, nil, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
//            
//            for(int i = 0; i != bufList.mBuffers->mNumberChannels; ++i)
//            {
//                std::reverse((short*)((char*)bufList.mBuffers->mData + (bufList.mBuffers->mDataByteSize / bufList.mBuffers->mNumberChannels) * i), (short*)((char*)bufList.mBuffers->mData + (bufList.mBuffers->mDataByteSize / bufList.mBuffers->mNumberChannels) * (i + 1)));
//            }
//
//            CMSampleBufferSetDataBufferFromAudioBufferList(tmpSample, kCFAllocatorDefault, kCFAllocatorDefault, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &bufList);
        
            ////////////////////////
            
            
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(tmpSample);
            size_t len = CMBlockBufferGetDataLength(blockBufferRef);
            if(vecAudioData.size() < len / 2)
                vecAudioData.resize(len / 2);
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, len, vecAudioData.data());
            std::reverse(vecAudioData.begin(), vecAudioData.end());
            
            CMBlockBufferReplaceDataBytes(vecAudioData.data(), blockBufferRef, 0, len);
            CMSampleBufferSetDataBuffer(tmpSample, blockBufferRef);
        
            [audioSamples addObject:(__bridge id)tmpSample];
            CFRelease(tmpSample);
        }
    }
    
    readerVideoOutput = nil;
    readerAudioOutput = nil;
    reader = nil;
    
    // Initialize the writer
    __block AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outputVideoURL
                                                      fileType:AVFileTypeMPEG4
                                                         error:&error];
    NSDictionary *videoCompressionProps = @{ AVVideoAverageBitRateKey : @(videoTrack.estimatedDataRate) };
    
    NSDictionary *writerOutputSettings = @{
                                           AVVideoCodecKey : AVVideoCodecH264,
                                           AVVideoWidthKey : @(videoTrack.naturalSize.width),
                                           AVVideoHeightKey : @(videoTrack.naturalSize.height),
                                           AVVideoCompressionPropertiesKey : videoCompressionProps
                                           };
    
    AVAssetWriterInput *writerVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                                     outputSettings:writerOutputSettings
                                                                   sourceFormatHint:(__bridge CMFormatDescriptionRef)[videoTrack.formatDescriptions lastObject]];
    [writerVideoInput setExpectsMediaDataInRealTime:NO];
    
    if([writer canAddInput:writerVideoInput])
    {
        [writer addInput:writerVideoInput];
    }
    else
    {
        writerVideoInput = nil;
        videoSamples = nil;
        CGE_NSLog(@"❌Generate video failed!!\n");
        return block(NO);
    }

    
    AVAssetWriterInput *writerAudioInput = nil;
    
    if(audioSamples != nil)
    {
        NSDictionary *outputSettings = @
        {
            AVFormatIDKey : @(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey : @(audioChannelsPerFrame),
            AVSampleRateKey : @(audioSampleRate),
            AVChannelLayoutKey : [NSData data],
            AVEncoderBitRateKey : @(128000),
        };
        
        writerAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
        [writerAudioInput setExpectsMediaDataInRealTime:NO];
        
        if([writer canAddInput:writerAudioInput])
        {
            [writer addInput:writerAudioInput];
        }
        else
        {
            writerAudioInput = nil;
            audioSamples = nil;
        }
    }
    
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    NSInteger videoSampleCnt = videoSamples.count;
    NSInteger audioSampleCnt = audioSamples.count;
    
    NSInteger videoSampleIndex = 0, audioSampleIndex = 0;
    CMTime audioTimeCnt = kCMTimeZero;
    
    while(writerVideoInput || writerAudioInput)
    {
        OSStatus status = -1;
        CMSampleTimingInfo timeInfo = {0};
        
        if(writerVideoInput && writerVideoInput.readyForMoreMediaData)
        {
            CMSampleBufferRef originBuffer = (__bridge CMSampleBufferRef)videoSamples[videoSampleIndex];
           
            timeInfo.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(originBuffer);
            
            CMSampleBufferRef newSampleBuffer;
            status = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, (__bridge CMSampleBufferRef)videoSamples[videoSampleCnt - videoSampleIndex - 1], 1, &timeInfo, &newSampleBuffer);
            
            CGE_NSLog(@"video dur %g, pres %g, deco %g\n", CMTimeGetSeconds(timeInfo.duration), CMTimeGetSeconds(timeInfo.presentationTimeStamp), CMTimeGetSeconds(timeInfo.decodeTimeStamp));
            
            if(status == 0)
            {
                [writerVideoInput appendSampleBuffer:newSampleBuffer];
            }
            else
            {
                CGE_NSLog(@"‼️Invalid video sample buffer detected!!");
            }
            
            CFRelease(newSampleBuffer);
           
            if(++videoSampleIndex >= videoSampleCnt)
            {
                [writerVideoInput markAsFinished];
                writerVideoInput = nil;
                videoSamples = nil;
            }
        }
        
        if(writerAudioInput && writerAudioInput.readyForMoreMediaData)
        {
            CMSampleBufferRef dstBuffer = (__bridge CMSampleBufferRef)audioSamples[audioSampleCnt - audioSampleIndex - 1];
            
            timeInfo.duration = CMSampleBufferGetDuration(dstBuffer);

            timeInfo.presentationTimeStamp = audioTimeCnt;
            audioTimeCnt = CMTimeAdd(timeInfo.presentationTimeStamp, timeInfo.duration);

            CMSampleBufferRef newSampleBuffer;
            status = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, dstBuffer, 1, &timeInfo, &newSampleBuffer);

            CGE_NSLog(@"audio dur %g, pres %g\n", CMTimeGetSeconds(timeInfo.duration), CMTimeGetSeconds(timeInfo.presentationTimeStamp));
            
            if(status == 0)
            {
                [writerAudioInput appendSampleBuffer:newSampleBuffer];
            }
            else
            {
                CGE_NSLog(@"‼️Invalid audio sample buffer detected!!");
            }
            
            CFRelease(newSampleBuffer);
            
            if(++audioSampleIndex >= audioSampleCnt)
            {
                [writerAudioInput markAsFinished];
                writerAudioInput = nil;
                audioSamples = nil;
            }
        }

        if(status != 0)
        {
            [NSThread sleepForTimeInterval:0.02];
        }
        
        CGE_NSLog_Code
        (
        CGE_NSLog(@"index : %d, %d\n", (int)videoSampleIndex, (int)audioSampleIndex);
        )
        
    }
    
    [writer finishWritingWithCompletionHandler:^{
        writer = nil;
        block(YES);
    }];
}

#define FPS_LIMIT  40.0  //避免超高帧率视频等待时间过长

+ (void)recompressVideo:(NSURL *)outputVideoURL inputURL:(NSURL *)inputVideo setting:(NSDictionary *)outputVideoSetting completionHandler:(void (^)(BOOL))block
{
    CGE_NSLog(@"recompressVideo start...");
    
    CGEAssert(block != nil);
    
    {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        if(![fileManager fileExistsAtPath:[inputVideo path]])
        {
            return block(NO);
        }
        
        if ([fileManager fileExistsAtPath:[outputVideoURL path]])
            [fileManager removeItemAtPath:[outputVideoURL path] error:nil];
    }
    
    // Initialize the reader
    AVAsset* asset = [AVAsset assetWithURL:inputVideo];
    NSError* error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
    NSArray<AVAssetTrack*>* audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    if(!(reader && videoTrack))
    {
        return block(NO);
    }
    
    NSDictionary *readerOutputSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) };

    AVAssetReaderTrackOutput* readerVideoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                             outputSettings:readerOutputSettings];
    readerVideoOutput.alwaysCopiesSampleData = NO;
    
    if([reader canAddOutput:readerVideoOutput])
        [reader addOutput:readerVideoOutput];
    else return block(NO);
    
    NSMutableArray<AVAssetReaderTrackOutput*>* readerAudioOutputs = nil;
    Float64 audioSampleRate = 44100;
    UInt32 audioChannelsPerFrame = 1;
    
    if(audioTracks != nil && audioTracks.count != 0)
    {
        readerAudioOutputs = [[NSMutableArray alloc] init];
        for(AVAssetTrack* audioTrack in audioTracks)
        {
            NSArray* formatDesc = [audioTrack formatDescriptions];
            NSDictionary* audioSettings = nil;
            if(formatDesc.count != 0)
            {
                CMAudioFormatDescriptionRef descRef = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:0];
                const AudioStreamBasicDescription* pcmAudioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(descRef);
                
                audioChannelsPerFrame = pcmAudioDesc->mChannelsPerFrame;
                audioSampleRate = pcmAudioDesc->mSampleRate;
                audioSettings = @{
                                  AVFormatIDKey : @(kAudioFormatLinearPCM),
                                  AVSampleRateKey : @(audioSampleRate),
                                  AVNumberOfChannelsKey : @(audioChannelsPerFrame),
                                  };
            }
            else
            {
                audioSettings = @{ AVFormatIDKey : @(kAudioFormatLinearPCM) };
            }
            
            AVAssetReaderTrackOutput* readerAudioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:audioSettings];
            readerAudioOutput.alwaysCopiesSampleData = NO;
            if([reader canAddOutput:readerAudioOutput])
            {
                [reader addOutput:readerAudioOutput];
                [readerAudioOutputs addObject:readerAudioOutput];
            }
            else
            {
                CGE_NSLog(@"Add audio output failed!\n");
            }
            
        }
    }
    
    //////////
    
    __block AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outputVideoURL
                                                      fileType:AVFileTypeMPEG4
                                                         error:&error];
    NSDictionary *writerOutputSettings = outputVideoSetting ? outputVideoSetting : @{
                                           AVVideoCodecKey : AVVideoCodecH264,
                                           AVVideoWidthKey : @(videoTrack.naturalSize.width),
                                           AVVideoHeightKey : @(videoTrack.naturalSize.height),
                                           AVVideoCompressionPropertiesKey : @{ AVVideoAverageBitRateKey : @(videoTrack.estimatedDataRate) }
                                           };
    
    AVAssetWriterInput *writerVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                                          outputSettings:writerOutputSettings
                                                                        sourceFormatHint:(__bridge CMFormatDescriptionRef)[videoTrack.formatDescriptions lastObject]];
    [writerVideoInput setExpectsMediaDataInRealTime:NO];
    
    if([writer canAddInput:writerVideoInput])
    {
        [writer addInput:writerVideoInput];
    }
    else
    {
        writerVideoInput = nil;
        CGE_NSLog(@"❌Generate video failed!!\n");
        return block(NO);
    }
    
    NSMutableArray<AVAssetWriterInput*>* writerAudioInputs = nil;
    
    if(readerAudioOutputs != nil && readerAudioOutputs.count != 0)
    {
        NSDictionary *outputSettings = @
        {
            AVFormatIDKey : @(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey : @(audioChannelsPerFrame),
            AVSampleRateKey : @(audioSampleRate),
            AVChannelLayoutKey : [NSData data]
//            AVEncoderBitRateKey : @(128000),
        };
        
        writerAudioInputs = [[NSMutableArray alloc] init];
        
        for(int i = 0; i != readerAudioOutputs.count; ++i)
        {
            AVAssetWriterInput* writerAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
            [writerAudioInput setExpectsMediaDataInRealTime:NO];
            
            if([writer canAddInput:writerAudioInput])
            {
                [writer addInput:writerAudioInput];
                [writerAudioInputs addObject:writerAudioInput];
            }
            else
            {
                CGE_NSLog(@"Add audio input failed!\n");
            }
        }
        
    }
    
    //////////
    
    [reader startReading];
    [writer setShouldOptimizeForNetworkUse:YES];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    if((writerAudioInputs != nil || readerAudioOutputs != nil) &&
       (writerAudioInputs.count == 0 || writerAudioInputs.count != readerAudioOutputs.count))
    {
        writerAudioInputs = nil;
        readerAudioOutputs = nil;
        CGE_NSLog(@"❌Invalid audio config, the video will be muted.");
    }

    int fpsCount = 0;
    
    while(writerVideoInput != nil || writerAudioInputs != nil)
    {
        if(writerVideoInput && writerVideoInput.readyForMoreMediaData)
        {
            CMSampleBufferRef videoSample = [readerVideoOutput copyNextSampleBuffer];
            if(videoSample != nil)
            {
                if(FPS_LIMIT > 0)
                {
                    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(videoSample);
                    double currTime = CMTimeGetSeconds(currentSampleTime);
                    int maxFrameForNow = currTime * FPS_LIMIT + 5;
                    if(fpsCount > maxFrameForNow)
                    {
                        CGE_LOG_INFO("Too many frames, skip...");
                        CFRelease(videoSample);
                        continue;
                    }
                    
                    ++fpsCount;
                }
                [writerVideoInput appendSampleBuffer:videoSample];
                CFRelease(videoSample);
            }
            else
            {
                [writerVideoInput markAsFinished];
                writerVideoInput = nil;
                readerVideoOutput = nil;
            }
        }
        
        if(writerAudioInputs != nil)
        {
            for(int i = 0; i < writerAudioInputs.count; )
            {
                AVAssetWriterInput* input = writerAudioInputs[i];
                AVAssetReaderTrackOutput* output = readerAudioOutputs[i];
                
                if(input && input.readyForMoreMediaData)
                {
                    CMSampleBufferRef audioSample = [output copyNextSampleBuffer];
                    if(audioSample != nil)
                    {
                        [input appendSampleBuffer:audioSample];
                        CFRelease(audioSample);
                        ++i;
                    }
                    else
                    {
                        [input markAsFinished];
                        [writerAudioInputs removeObject:input];
                        [readerAudioOutputs removeObject:output];
                    }
                }
                else ++i;
            }
            
            if(writerAudioInputs.count == 0 || readerAudioOutputs.count == 0)
            {
                writerAudioInputs = nil;
                readerAudioOutputs = nil;
            }
        }
    }
    
    reader = nil;
    
    CGE_NSLog(@"recompress finishing...");
    [writer finishWritingWithCompletionHandler:^{
        CGE_NSLog(@"finish in block...");
        block(YES);
        writer = nil;
    }];
}

@end










