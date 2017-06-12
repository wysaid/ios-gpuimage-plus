/*
 * cgeVideoPlayer.mm
 *
 *  Created on: 2015-10-14
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeVideoPlayer.h"
#import "cgeVideoHandlerCV.h"

#define ONE_FRAME_DURATION 0.1

using namespace CGE;

@interface CGEVideoPlayer() <AVPlayerItemOutputPullDelegate>
{
//    dispatch_queue_t _myVideoOutputQueue;
    id _notificationToken;
    id _timeObserver;
    __unsafe_unretained NSString* _statusObserverPath;
    BOOL _statusObserverUsed;
    int _retryTimes;
}

@end

@implementation CGEVideoPlayer

- (id)initWithContext:(CGESharedGLContext *)sharedContext
{
    self = [super initWithContext:sharedContext];
    
    if(self)
    {
        _avPlayer = [[AVPlayer alloc] init];
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [_displayLink setPaused:YES];
        
        // Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
        NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
        _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
        [_videoOutput setDelegate:self queue:self.sharedContext.contextQueue];
        assert(_videoOutput != nil);
        
//        _myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
//        assert(_myVideoOutputQueue != nil);
        
        _statusObserverPath = @"avPlayer.currentItem.status";
        _statusObserverUsed = NO;
        _requestFirstFrameThenPause = NO;
        
        _videoSema = dispatch_semaphore_create(1);
    }
    
    return self;
}

#pragma mark - AVPlayerItemOutputPullDelegate

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
    CGE_LOG_INFO("\n=== outputMediaDataWillChange ===\n");
    if(_videoOutput == nil || _loadingStatus == CGEVideoPlayerLoadingStatus_LoadOK)
        return;
    
    CMTime cmTime;
    if (!([_videoOutput hasNewPixelBufferForItemTime:(cmTime = kCMTimeZero)] ||
          [_videoOutput hasNewPixelBufferForItemTime:(cmTime = CMTimeMake(1, 100))] ||
          [_videoOutput hasNewPixelBufferForItemTime:(cmTime = CMTimeMake(1, 10))]))
    {
        if(_retryTimes < 4)
        {
            ++_retryTimes;
            
            [[_avPlayer currentItem] removeOutput:_videoOutput];
            
            [_videoOutput setDelegate:nil queue:nil];
            
            NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
            _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
            [_videoOutput setDelegate:self queue:self.sharedContext.contextQueue];
            
            [[_avPlayer currentItem] addOutput:_videoOutput];
            [self.displayLink setPaused:YES];
            
            [_videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
            CGE_NSLog(@"❌The output is broken, retry...");
            _loadingStatus = CGEVideoPlayerLoadingStatus_Loading;
            return;
        }
        else
        {
            CGE_NSLog(@"❌Video loading failed!!!");
        }
    }
    
    CGE_NSLog(@"👍Video loading OK!");
    
    if(_requestFirstFrameThenPause)
    {
        if([_videoOutput hasNewPixelBufferForItemTime:cmTime])
        {
            //强制刷新出第一帧
            CVPixelBufferRef pixelBuffer = [[self videoOutput] copyPixelBufferForItemTime:cmTime itemTimeForDisplay:nil];
            
            if (pixelBuffer != nil)
            {
                if(dispatch_semaphore_wait(_videoSema, DISPATCH_TIME_NOW) == 0)
                    [self processVideoFrame:pixelBuffer];
            }
            
            CGE_NSLog(@"已加载出第一帧, 暂停!");
            [_avPlayer pause];
        }
        else
        {
            CGE_NSLog(@"未自动加载出第一帧, time: %g, status: %d", CMTimeGetSeconds(cmTime), (int)_avPlayer.currentItem.status);
        }
        
        _requestFirstFrameThenPause = NO;
    }
    else
    {
        // Restart display link.
        [_displayLink setPaused:NO];
    }
    
    _loadingStatus = CGEVideoPlayerLoadingStatus_LoadOK;
}

//- (void)outputSequenceWasFlushed:(AVPlayerItemOutput *)output
//{
//    CGE_NSLog(@"outputSequenceWasFlushed...");
//}

- (void)dealloc
{
    [self clear];
}

- (void)clear
{
    if(self.sharedContext)
    {
        [self.sharedContext syncProcessingQueue:^{
            _updateDelegate = nil;
            _playerDelegate = nil;
            
            [self removePlayerStatusNotification];
            
            if(_avPlayer)
            {
                [_avPlayer pause];
                [self removeNotificationForPlayerItem:[_avPlayer currentItem]];
                [self removePeriodicNotificationForPlayerItem];
                _avPlayer = nil;
            }
            
            if(_videoOutput)
            {
                [_videoOutput setDelegate:nil queue:nil];
                _videoOutput = nil;
            }
            
            [_displayLink setPaused:YES];
            [_displayLink invalidate];
            _displayLink = nil;
            
        }];
        
        [super clear];
    }
}

- (void)startWithURL:(NSURL*)url
{
    [self startWithURL:url completionHandler:^(NSError* err){
        if(err)
        {
            CGE_NSLog(@"start video failed: %@", err);
        }
        else
        {
            [_avPlayer play];
        }
    }];
}

- (void)startWithURL:(NSURL*)url completionHandler:(void (^)(NSError*))block
{
    AVAsset* asset = [AVAsset assetWithURL:url];
    [self startWithAsset:asset completionHandler:block];
}

- (void)startWithAsset:(AVAsset *)asset completionHandler:(void (^)(NSError *))block
{
    if(block == nil)
        block = ^(NSError* err) { if(err) CGE_NSLog(@"startWithURL failed: %@", err); };
    
    [self.sharedContext syncProcessingQueue:^{
        
        if(!_displayLink.paused)
        {
            [_displayLink setPaused:YES];
        }
        
        if([self isPlaying])
        {
            [_avPlayer pause];
        }
        
        if(_videoOutput != nil)
        {
            [[_avPlayer currentItem] removeOutput:_videoOutput];
            _videoOutput = nil;
        }
    }];
    
    _retryTimes = 0;
    _loadingStatus = CGEVideoPlayerLoadingStatus_Loading;
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    
    if(item == nil || asset == nil)
    {
        CGE_LOG_ERROR("Invalid URL for player...");
        block([NSError errorWithDomain:@"InvalidURL" code:0 userInfo:nil]);
    }
    
    __weak CGEVideoPlayer* weakSelf = self;
    
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        
        NSError* err;
        
        if ([asset statusOfValueForKey:@"tracks" error:&err] == AVKeyValueStatusLoaded)
        {
            NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
            if ([tracks count] > 0)
            {
                // Choose the first video track.
                AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
                
                [videoTrack loadValuesAsynchronouslyForKeys:@[@"preferredTransform"] completionHandler:^{
                    
                    NSError* err;
                    if ([videoTrack statusOfValueForKey:@"preferredTransform" error:&err] == AVKeyValueStatusLoaded)
                    {
                        
                        //解决 video 旋转问题 2015-12-3
                        
                        CGAffineTransform preferredTransform = [videoTrack preferredTransform];
                        
                        /*
                         The orientation of the camera while recording affects the orientation of the images received from an AVPlayerItemVideoOutput. Here we compute a rotation that is used to correctly orientate the video.
                         */
                        double rotation = atan2(preferredTransform.b, preferredTransform.a);
                        CGE_NSLog(@"The video preferred rotation: %g", rotation);
                        
                        [weakSelf.sharedContext syncProcessingQueue:^{
                            [weakSelf.sharedContext makeCurrent];
                            
                            if(weakSelf.avPlayer == nil)
                                return ;
                            
                            if(rotation != 0)
                            {
                                CGE_FRAMERENDERER_VIDEOHANDLER_TYPE* videoHandler = (CGE_FRAMERENDERER_VIDEOHANDLER_TYPE*)[weakSelf getVideoHandler];
                                
                                if(videoHandler != nullptr)
                                {
                                    auto drawer = videoHandler->getYUVDrawer();
                                    drawer->setRotation(rotation);
                                    
                                    if(fabs(sin(rotation)) > 0.1) // 需要交换宽高
                                    {
                                        [weakSelf setReverseTargetSize:YES];
                                    }
                                    else
                                    {
                                        [weakSelf setReverseTargetSize:NO];
                                    }
                                    
                                    videoHandler->setReverseTargetSize(weakSelf.reverseTargetSize);
                                }
                            }
                            
                            weakSelf.videoResolution = [videoTrack naturalSize];
                            
                            if(weakSelf.reverseTargetSize)
                            {
                                weakSelf.videoResolution = CGSizeMake(weakSelf.videoResolution.height, weakSelf.videoResolution.width);
                            }
                        }];
                        
                        [CGESharedGLContext mainASyncProcessingQueue:^{
                            
                            if(weakSelf)
                            {
                                if(weakSelf.playerDelegate && [weakSelf.playerDelegate respondsToSelector:@selector(videoResolutionChanged:)])
                                {
                                    [weakSelf.playerDelegate videoResolutionChanged: weakSelf.videoResolution];
                                }
                                
                                [weakSelf addPeriodicNotificationForPlayerItem];
                                
                                [weakSelf removeNotificationForPlayerItem:[weakSelf.avPlayer currentItem]];
                                [weakSelf addNotificationForPlayerItem:item];
                                
                                [weakSelf addPlayerStatusNotification];
                                
                                if(weakSelf.videoOutput == nil)
                                {
                                    NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
                                    weakSelf.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
                                    [weakSelf.videoOutput setDelegate:weakSelf queue:weakSelf.sharedContext.contextQueue];
                                    assert(weakSelf.videoOutput != nil);
                                }
                                
                                [item addOutput:weakSelf.videoOutput];
                                [weakSelf.avPlayer replaceCurrentItemWithPlayerItem:item];
                                [weakSelf.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
                                
                                CGE_LOG_INFO("\n===requestNotificationOfMediaDataChangeWithAdvanceInterval\n");
                                
                                block(nil);
                                
                                if([weakSelf isPlaying])
                                    weakSelf.requestFirstFrameThenPause = NO;
                                else if(weakSelf.requestFirstFrameThenPause)
                                    [weakSelf.avPlayer play];
                            }
                            else
                            {
                                block([NSError errorWithDomain:@"❌The Player Become Nil!!" code:0 userInfo:nil]);
                            }
                        }];
                    }
                    else
                    {
                        CGE_NSLog(@"Get video transform failed: %@", err);
                        block(err);
                    }
                    
                }];
            }
        }
        else
        {
            CGE_NSLog(@"Start playing video failed, err: %@", err);
            block(err);
        }
        
    }];
}

- (void)displayLinkCallback:(CADisplayLink *)sender
{
//    CGE_NSLog(@"Current: %@, Main: %@\n", [NSRunLoop currentRunLoop], [NSRunLoop mainRunLoop]);
    
    if(dispatch_semaphore_wait(_videoSema, DISPATCH_TIME_NOW) != 0)
    {
//        CGE_LOG_INFO("Video Frame Skip...\n");
        return;
    }
    
    CMTime outputItemTime = kCMTimeInvalid;
    
    CGE_NSLog_Code
    (
     if(_videoOutput == nil)
     {
         CGE_NSLog(@"❌ videoOutput is nil...");
         [_displayLink setPaused:YES];
     }
    )
    
    // Calculate the nextVsync time which is when the screen will be refreshed next.
    CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);
    
    outputItemTime = [_videoOutput itemTimeForHostTime:nextVSync];
    
    if ([[self videoOutput] hasNewPixelBufferForItemTime:outputItemTime])
    {
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [_videoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:nil];
        
        if (pixelBuffer != nil)
        {
            [self processVideoFrame:pixelBuffer];
            return ;
        }
    }
    
    dispatch_semaphore_signal(_videoSema);
}

- (void)processVideoFrame:(CVPixelBufferRef)pixBuffer
{
    [self.sharedContext asyncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        CGE_FRAMERENDERER_VIDEOHANDLER_TYPE* videoHandler = (CGE_FRAMERENDERER_VIDEOHANDLER_TYPE*)[self getVideoHandler];
        
        if(videoHandler != nullptr && videoHandler->updateFrameWithCVImageBuffer(pixBuffer))
        {
            if(videoHandler->getFilterNum() != 0)
            {
                [self.renderLock lock];
                videoHandler->processingFilters();
                [self.renderLock unlock];
            }
            else glFinish();
            
            if(_updateDelegate)
                [_updateDelegate frameUpdated];
        }
        
        CFRelease(pixBuffer);
        dispatch_semaphore_signal(_videoSema);
    }];
}

- (void)addNotificationForPlayerItem:(AVPlayerItem *)item
{
    _avPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _notificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:item queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        // Simple item playback rewind.
        if(_playerDelegate && [_playerDelegate respondsToSelector:@selector(videoPlayingComplete:playItem:)])
        {
            [_playerDelegate videoPlayingComplete:self playItem:item];
        }
        else
        {
            [_avPlayer pause];
        }
    }];
}

- (void)removeNotificationForPlayerItem:(AVPlayerItem *)item
{
    if (_notificationToken && item)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:_notificationToken name:AVPlayerItemDidPlayToEndTimeNotification object:item];
        _notificationToken = nil;
    }
}

- (void)addPeriodicNotificationForPlayerItem
{
    if(_playerDelegate && [_playerDelegate respondsToSelector:@selector(playTimeUpdated:)])
    {
        if(_timeObserver == nil)
        {
            CMTime timeInterval = [_playerDelegate respondsToSelector:@selector(playTimeUpdateInterval)] ? [_playerDelegate playTimeUpdateInterval] : CMTimeMakeWithSeconds(1, 1);

            __weak CGEVideoPlayer* weakSelf = self;
            _timeObserver = [_avPlayer addPeriodicTimeObserverForInterval:timeInterval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
                [weakSelf.playerDelegate playTimeUpdated:time];
            }];
        }
    }
    else
    {
        [self removePeriodicNotificationForPlayerItem];
    }
}

- (void)removePeriodicNotificationForPlayerItem
{
    if(_timeObserver)
    {
        [_avPlayer removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
}

- (void)addPlayerStatusNotification
{
    if(_playerDelegate && [_playerDelegate respondsToSelector:@selector(playerStatusChanged:)])
    {
        if(!_statusObserverUsed)
        {
            [self addObserver:self forKeyPath:_statusObserverPath options:NSKeyValueObservingOptionNew context:nil];
            _statusObserverUsed = YES;
        }
    }
    else
    {
        CGE_NSLog(@"No receiver is set...");
        [self removePlayerStatusNotification];
    }
}

- (void)removePlayerStatusNotification
{
    if(_statusObserverUsed)
    {
        @try {
            [self removeObserver:self forKeyPath:_statusObserverPath context:nil];
        }
        @catch (NSException *exception) {
            CGE_NSLog(@"Error occurred when removePlayerStatusNotification: %@", exception);
            assert(0);
        }
        @finally {
            _statusObserverUsed = NO;
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if([keyPath isEqualToString:_statusObserverPath])
    {

        if(_playerDelegate && [_playerDelegate respondsToSelector:@selector(playerStatusChanged:)])
        {
            [_playerDelegate playerStatusChanged:[[_avPlayer currentItem] status]];
        }
        else
        {
            CGE_NSLog(@"😂Observer is useless, destroying...");
            [self removePlayerStatusNotification];
        }
    }
}

- (void)setPlayerDelegate:(id<CGEVideoPlayerDelegate>)playerDelegate
{
    _playerDelegate = playerDelegate;
    if(_avPlayer && [_avPlayer currentItem])
    {
        [self addPeriodicNotificationForPlayerItem];
        [self addPlayerStatusNotification];
    }
}

- (BOOL)isPlaying
{
    return [_avPlayer rate] != 0 && ![_avPlayer error];
}

- (void)restart
{
    [[_avPlayer currentItem] seekToTime:kCMTimeZero];
    [self resume];
}

- (void)pause
{
    [_avPlayer pause];
    [_displayLink setPaused:YES];
}

- (void)resume
{
    if(_avPlayer.status != AVPlayerStatusReadyToPlay)
    {
        CGE_NSLog(@"‼️Invalid Player Status!\n");
    }
    
    [_avPlayer play];
    _requestFirstFrameThenPause = NO;
    
    if(_loadingStatus == CGEVideoPlayerLoadingStatus_LoadOK && [_displayLink isPaused])
    {
        [_displayLink setPaused:NO];
    }
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

@end









