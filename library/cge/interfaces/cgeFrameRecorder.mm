/*
 * cgeFrameRecorder.mm
 *
 *  Created on: 2015-12-1
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeFrameRecorder.h"
#import "cgeVideoHandlerCV.h"
#import "cgeUtilFunctions.h"

using namespace CGE;

@interface CGEFrameRecorder()

@end

@implementation CGEFrameRecorder

- (id)initWithContext :(CGESharedGLContext*)sharedContext
{
    self = [super initWithContext:sharedContext];
    if(self)
    {
        _shouldPassthroughAudio = NO;
    }

    return self;
}

- (void)dealloc
{
    [self clear];

    CGE_LOG_INFO("###Frame Recorder dealloc...\n");
}

- (void)clear
{
    if(_videoWriter != nil)
    {
        [_videoWriter clear];
        _videoWriter = nil;
    }

    _updateDelegate = nil;

    [super clear];
}

- (void)startRecording :(NSURL*)videoURL size:(CGSize)videoSize
{
    [self startRecording:videoURL size:videoSize outputSetting:nil];
}

- (void)startRecording:(NSURL *)videoURL size:(CGSize)videoSize outputSetting:(NSDictionary *)outputSetting
{
    if(_cacheVideoURL == nil)
    {
        _cacheVideoURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"cgeCacheVideo_%d.mp4", rand()]]];

        if(_cacheVideoURL == nil)
        {
            _cacheVideoURL = videoURL;
        }
    }

    if([[NSFileManager defaultManager] fileExistsAtPath:[_cacheVideoURL path]])
    {
        [[NSFileManager defaultManager] removeItemAtPath:[_cacheVideoURL path] error:nil];
    }

    BOOL muted = NO;
    
    if(outputSetting)
    {
        id _muted = [outputSetting objectForKey:@"mute"];
        if(_muted)
        {
            muted = [_muted boolValue];
            if([outputSetting count] == 1)
            {
                outputSetting = nil;
            }
            else
            {
                NSMutableDictionary* dict = [outputSetting mutableCopy];
                [dict removeObjectForKey:@"mute"];
                outputSetting = dict;
            }
        }
    }
    
    _outputVideoURL = videoURL;
    _videoWriter = [[CGEVideoWriter alloc] initWithMovieURL:_cacheVideoURL size:videoSize fileType:AVFileTypeMPEG4 outputSettings:outputSetting];
    
    if(muted)
    {
        [_videoWriter setHasAudioTrack:NO];
    }
    else
    {
        if(![_videoWriter hasAudioTrack])
        {
            [_videoWriter setShouldPassthroughAudio:_shouldPassthroughAudio];
            [_videoWriter setHasAudioTrack:YES];            
        }
    }
    
    [_videoWriter startRecording];
    _isRecording = YES;
}

- (void)endRecording:(void (^)())completionHandler withQuality:(NSString *)quality shouldOptimizeForNetworkUse:(BOOL)shouldOptimize
{
    if(!_isRecording)
    {
        CGE_NSLog(@"❌Error: endRecording without starting!\n");
        completionHandler();
        return;
    }
    
    [self.sharedContext syncProcessingQueue:^{
        _isRecording = NO;
    }];
    
    if(_cacheVideoURL == _outputVideoURL || _cacheVideoURL == nil || quality == nil)
    {
        [_videoWriter finishRecordingWithCompletionHandler:^{
            
            NSFileManager* fileManager = [NSFileManager defaultManager];
            
            if([fileManager fileExistsAtPath:_outputVideoURL.path])
            {
                [fileManager removeItemAtPath:_outputVideoURL.path error:nil];
            }
            
            if([fileManager fileExistsAtPath:[_cacheVideoURL path]])
            {
                CGE_NSLog(@"🙊Saving the origin file!");
                NSError* err = nil;
                [fileManager moveItemAtPath:[_cacheVideoURL path] toPath:[_outputVideoURL path] error:&err];
                if(err)
                {
                    CGE_NSLog(@"Err: %@", err);
                }
                
                if(completionHandler)
                    completionHandler();
            }
        }];
    }
    else
    {
        void (^finishBlock)(void (^)(void)) = ^(void (^compressOK)(void)){
            
            [CGEVideoWriter compressVideo:_outputVideoURL inputURL:_cacheVideoURL quality:quality shouldOptimizeForNetworkUse:shouldOptimize completionHandler:^(NSError *err) {
                
                if(!err)
                {
                    CGE_NSLog(@"😋Video compressed! Quality: %@", quality);
                    compressOK();
                }
                else
                {
                    NSFileManager* fileManager = [NSFileManager defaultManager];
                    if([fileManager fileExistsAtPath:[_cacheVideoURL path]])
                    {
                        CGE_NSLog(@"😂Video compress failed! Saving the origin file! err: %@\n", err);
                        NSError* err = nil;
                        [fileManager moveItemAtPath:[_cacheVideoURL path] toPath:[_outputVideoURL path] error:&err];
                        if(err)
                        {
                            CGE_NSLog(@"Err: %@", err);
                        }
                        
                        compressOK();
                    }
                }
            }];
        };
        
        if(completionHandler)
        {
            [_videoWriter finishRecordingWithCompletionHandler:^{
                finishBlock(completionHandler);
            }];
        }
        else
        {
            //Force thread waiting until 'finishBlock' finished.
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [_videoWriter finishRecording];
            
            finishBlock(^{
                dispatch_semaphore_signal(semaphore);
            });
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
    }
    
    _videoWriter = nil;

}

- (void)endRecording:(void (^)(void))completionHandler
{
    [self endRecording:completionHandler withQuality:nil shouldOptimizeForNetworkUse:YES];
}

- (void)endRecording :(void (^)(void))completionHandler withCompressionLevel:(int)level
{
    if(level <= 0)
    {
        [self endRecording:completionHandler withQuality:nil shouldOptimizeForNetworkUse:YES];
    }
    else
    {
        static NSString* compressQualities[] = {
            AVAssetExportPresetHighestQuality,
            AVAssetExportPresetMediumQuality,
            AVAssetExportPresetLowQuality
        };
        
        static const int maxQualityNum = sizeof(compressQualities) / sizeof(*compressQualities) - 1;
        
        --level;
        
        if(level > maxQualityNum)
            level = maxQualityNum;
        
        NSString* compressQuality = compressQualities[level];
        [self endRecording:completionHandler withQuality:compressQuality shouldOptimizeForNetworkUse:YES];
    }
    
}

- (void)cancelRecording
{
    _isRecording = NO;
    [_videoWriter cancelRecording];
    _videoWriter = nil;

}


@end










