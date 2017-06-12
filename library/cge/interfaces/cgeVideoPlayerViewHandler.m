/*
 * cgeVideoPlayerViewHandler.m
 *
 *  Created on: 2015-10-13
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeVideoPlayerViewHandler.h"

@implementation CGEVideoPlayerViewHandler

- (id)init
{
//    self = [super init];
//    [self setup];
    return nil;
}

- (id)initWithGLKView:(GLKView *)glkView
{
    self = [super init];
    [self setup];
    [self setGlkView:glkView];
    return self;
}

- (void)setup
{
    if(_videoPlayer == nil)
    {
        _videoPlayer = [[CGEVideoPlayer alloc] initWithContext:[CGESharedGLContext globalGLContext]];
        [_videoPlayer setUpdateDelegate:self];
    }

    _shouldResetViewport = NO;
    _shouldUpdateViewport = NO;
}

- (void)setGlkView:(GLKView *)glkView
{
    _glkView = glkView;
//    [_glkView setDelegate:self];
    [_glkView setDrawableColorFormat:GLKViewDrawableColorFormatRGBA8888];
    [_glkView setContext:[_videoPlayer.sharedContext context]];
    [_glkView setEnableSetNeedsDisplay:NO];
    [_glkView setBackgroundColor:[UIColor clearColor]];
}

- (void)dealloc
{
    [self clear];
    CGE_NSLog(@"###video player dealloc...\n");
}

- (void)clear
{
    if(_videoPlayer != nil)
    {
        [_videoPlayer clear];
        _videoPlayer = nil;
    }
    
    _glkView = nil;
    [EAGLContext setCurrentContext:nil];
}

- (void)frameUpdated
{
    [_glkView bindDrawable];
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if(_shouldUpdateViewport)
    {
        if(_shouldResetViewport)
            [self _updateViewArea];
        glViewport(_viewArea.origin.x, _viewArea.origin.y, _viewArea.size.width, _viewArea.size.height);
    }
    
    [_videoPlayer fastDrawResult];
    [_glkView display];
    
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

- (void)setFilterIntensity:(float)value
{
    [_videoPlayer setFilterIntensity:value];
}

- (void)setFilterWithConfig:(const char *)config
{
    [_videoPlayer setFilterWithConfig:config];
}

- (void)setMaskUIImage:(UIImage *)image
{
    [_videoPlayer setMaskUIImage:image];
}

- (void)setMaskTexture:(GLuint)maskTexture textureAspectRatio:(float)aspectRatio
{
    _maskAspectRatio = aspectRatio;
    [_videoPlayer setMaskTexture:maskTexture textureAspectRatio:aspectRatio];
}

- (BOOL)isUsingMask
{
    return [_videoPlayer isUsingMask];
}

- (void)startWithURL:(NSURL*) url
{
    [_videoPlayer startWithURL:url];
}

- (void)startWithURL:(NSURL *)url completionHandler:(void (^)(NSError*))block
{
    [_videoPlayer startWithURL:url completionHandler:block];
}

- (void)startWithAsset:(AVAsset *)asset completionHandler:(void (^)(NSError *))block
{
    [_videoPlayer startWithAsset:asset completionHandler:block];
}

- (BOOL)isPlaying
{
    return [_videoPlayer isPlaying];
}

- (void)restart
{
    [_videoPlayer restart];
}

- (void)pause
{
    [_videoPlayer pause];
}

- (void)resume
{
    [_videoPlayer resume];
}

- (CMTime)videoDuration
{
    if([self status] == AVPlayerItemStatusReadyToPlay)
        return [[[_videoPlayer avPlayer] currentItem] duration];

    if([[[_videoPlayer avPlayer] currentItem] asset])
        return [[[[_videoPlayer avPlayer] currentItem] asset] duration];

    return kCMTimeInvalid;
}

- (CMTime)currentTime
{
    return [self status] == AVPlayerItemStatusReadyToPlay ? [[[_videoPlayer avPlayer] currentItem] currentTime] : kCMTimeZero;
}

- (AVPlayerItemStatus)status
{
    return [[[_videoPlayer avPlayer] currentItem] status];
}

- (void)_updateViewArea
{
    CGSize sz = [_videoPlayer videoResolution];
    [self _updateViewArea:sz.width / sz.height];
}

- (void)_updateViewArea:(float)ratio
{
    float viewWidth = _glkView.drawableWidth, viewHeight = _glkView.drawableHeight;
    
    if([_videoPlayer isUsingMask])
    {
        ratio = _maskAspectRatio;
    }

    float viewRatio = viewWidth / viewHeight;
    float s = ratio / viewRatio;

    float w, h;

    switch (_displayMode)
    {
        case CGEVideoPlayerViewDisplayModeAspectFill:
        {
            //保持比例撑满全部view(内容大于view)
            if(s > 1.0)
            {
                w = (int)(viewHeight * ratio);
                h = viewHeight;
            }
            else
            {
                w = viewWidth;
                h = (int)(viewWidth / ratio);
            }
        }
            break;
        case CGEVideoPlayerViewDisplayModeAspectFit:
        {
            //保持比例撑满全部view(内容小于view)
            if(s < 1.0)
            {
                w = (int)(viewHeight * ratio);
                h = viewHeight;
            }
            else
            {
                w = viewWidth;
                h = (int)(viewWidth / ratio);
            }
        }
            break;

        default:
            CGE_NSLog(@"Error occured, please check the code...");
            return;
    }

    _viewArea.size.width = w;
    _viewArea.size.height = h;
    _viewArea.origin.x = (viewWidth - w) / 2;
    _viewArea.origin.y = (viewHeight - h) / 2;
    _shouldResetViewport = NO;
}

- (void)setViewDisplayMode:(CGEVideoPlayerViewDisplayMode)mode
{
    _displayMode = mode;

    if(mode == CGEVideoPlayerViewDisplayModeDefault)
    {
        _shouldUpdateViewport = NO;
        _shouldResetViewport = NO;
    }
    else
    {
        _shouldResetViewport = YES;
        _shouldUpdateViewport = YES;
    }
}

@end






