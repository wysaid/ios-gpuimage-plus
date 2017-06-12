/*
 * cgeDynamicImageViewHandler.h
 *
 *  Created on: 2015-12-28
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "cgeDynamicImageViewHandler.h"
#import "cgeUtilFunctions.h"
#import "cgeImageHandlerIOS.h"
#include "cgeTextureUtils.h"
#include "cgeMultipleEffects.h"
#include <vector>

using namespace CGE;

typedef struct ImageFrame
{
    GLuint imageTexture;
    float delayTime;
}ImageFrame;

@interface CGEDynamicImageViewHandler()
{
    std::vector<ImageFrame> _vecImageFrames;
    ImageFrame* _lastImageFrame;
    double _currentStillTime;
    double _lastFrameTime;
    TextureDrawer* _frameDrawer;
}

@property (nonatomic) NSTimer* animTimer;

@end

@implementation CGEDynamicImageViewHandler

- (void)_setupView
{
    [super _setupView];
    
    if(_frameDrawer == nil)
    {
        [self.sharedContext syncProcessingQueue:^{
            [self.sharedContext makeCurrent];
            
            _frameDrawer = TextureDrawer::create();
//            _frameDrawer->setFlipScale(1.0f, -1.0f);
        }];
    }
}

- (void)clear
{
    [self clearTextures];
    
    if(_frameDrawer != nil)
    {
        [self.sharedContext syncProcessingQueue:^{
            [self.sharedContext makeCurrent];
            delete _frameDrawer;
            _frameDrawer = nil;
        }];
    }
    
    [super clear];
}

- (void)clearTextures
{
    [self stopAnimation];
    
    if(self.sharedContext != nil && !_vecImageFrames.empty())
    {
        [self.sharedContext syncProcessingQueue:^{
            [self.sharedContext makeCurrent];
            
            std::vector<GLuint> vecTex;
            vecTex.reserve(_vecImageFrames.size());
            
            for(auto& imageFrame : _vecImageFrames)
            {
                vecTex.push_back(imageFrame.imageTexture);
            }
            
            glDeleteTextures((int)vecTex.size(), vecTex.data());
            _vecImageFrames.clear();
            _currentImageIndex = 0;
        }];
    }
}

- (size_t)totalImages
{
    return _vecImageFrames.size();
}

- (BOOL)setUIImage:(UIImage *)image
{
    [self clearTextures];
    return [super setUIImage:image];
}

- (BOOL)setUIImagesWithConfig:(NSDictionary *)imageConfig startAnimation:(BOOL)doAnimation
{
    [self clearTextures];
    NSArray* imgArr = [imageConfig objectForKey:@"images"];
    NSArray* delayTimes = [imageConfig objectForKey:@"delayTimes"];
    float stableDelayTime = [[imageConfig objectForKey:@"stableDelayTime"] floatValue];
    
    if(imgArr == nil || (delayTimes == nil && stableDelayTime == 0.0f) || (delayTimes != nil && imgArr.count != delayTimes.count))
    {
        CGE_NSLog(@"❌Invalid image config!\n");
        return NO;
    }
    
    _vecImageFrames.reserve(imgArr.count);
    
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
        {
            CGE_IMAGEVIEW_IMAGEHANDLER_IOS* handler = [self getHandlerIOS];
            
            const CGESizei& sz = handler->getOutputFBOSize();
            UIImage* img = imgArr[0];
            int width = img.size.width;
            int height = img.size.height;
            
            if(sz.width != width || sz.height != height)
            {
                [self setImageSize:CGSizeMake(width, height)];
                handler->initWithRawBufferData(nil, width, height, CGE_FORMAT_RGBA_INT8, false);
                CGE_NSLog(@"handler reinit: width %d, height %d", width, height);
            }
        }
        
        for(int i = 0; i != imgArr.count; ++i)
        {
            UIImage* image = [imgArr objectAtIndex:i];
            float delay = delayTimes == nil ? stableDelayTime : [[delayTimes objectAtIndex:i] floatValue];
            
            CGETextureInfo tex = cgeUIImage2Texture(image);
            
            if(tex.name == 0)
            {
                CGE_NSLog(@"❌Create texture failed!!\n");
                return ;
            }
            
            ImageFrame frame = {
                tex.name, delay
            };
            
            _vecImageFrames.push_back(frame);
        }
    }];
    
    if(doAnimation)
        [self startAnimation];
    
    return !_vecImageFrames.empty();
}

- (BOOL)setGifImage:(CFURLRef)gifUrl
{
    CGImageSourceRef gifSource = CGImageSourceCreateWithURL(gifUrl, nil);
    
    if(gifSource == nil)
        return NO;
    
    size_t frameCnt = CGImageSourceGetCount(gifSource);
    
    if(frameCnt == 0)
    {
        CFRelease(gifSource);
        return NO;
    }
    
    
    [self clearTextures];
    
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
        //gif基本数据
//        NSDictionary* gifProp = (__bridge NSDictionary*)CGImageSourceCopyProperties(gifSource, nil);
        
        //gif
//        NSDictionary* gifDict = [gifProp objectForKey:(__bridge NSString*)kCGImagePropertyGIFDictionary];
        
//        int loopCount = [[gifDict objectForKey:(__bridge NSString*)kCGImagePropertyGIFLoopCount] integerValue];
        
//        CFRelease((__bridge CFTypeRef)gifProp);
        
        unsigned char* buffer = nil;
        size_t bufferLen = 0;
        
        CGE_IMAGEVIEW_IMAGEHANDLER_IOS* handler = [self getHandlerIOS];
        
        for(size_t i = 0; i < frameCnt; ++i)
        {
            CGImageRef frame = CGImageSourceCreateImageAtIndex(gifSource, i, nil);
            //        UIImage* image = [UIImage imageWithCGImage:frame];
            //        GLuint tex = cgeUIImage2Texture(image);
            
            size_t width = CGImageGetWidth(frame);
            size_t height = CGImageGetHeight(frame);
            size_t bufferSize = width * height * 4;
            
            const CGESizei& sz = handler->getOutputFBOSize();
            
            if(sz.width != width || sz.height != height)
            {
                [self setImageSize:CGSizeMake(width, height)];
                handler->initWithRawBufferData(nil, (int)width, (int)height, CGE_FORMAT_RGBA_INT8, false);
                CGE_NSLog(@"handler reinit: width %d, height %d", (int)width, (int)height);
            }
            
            if(bufferSize > bufferLen || buffer == nil)
            {
                bufferLen = bufferSize;
                buffer = (unsigned char*)realloc(buffer, (int)bufferLen);
            }
            
            GLuint tex = cgeCGImage2Texture(frame, buffer);
            
            NSDictionary* frameDict = (__bridge NSDictionary*)CGImageSourceCopyPropertiesAtIndex(gifSource, i, nil);
            
            NSDictionary* imageFrameDict = [frameDict objectForKey:(__bridge NSString*)kCGImagePropertyGIFDictionary];
            float delayTime = [[imageFrameDict objectForKey:(__bridge NSString*)kCGImagePropertyGIFDelayTime] floatValue];
            
            ImageFrame imageFrame = {
                tex, delayTime
            };
            
            _vecImageFrames.push_back(imageFrame);
            
            CFRelease((__bridge CFTypeRef)frameDict);
        }
        
        free(buffer);
        
    }];
    
    CFRelease(gifSource);
    
    return !_vecImageFrames.empty();
}

- (BOOL)saveAsGif:(NSURL *)gifUrl loopCount:(int)loopCount
{
    NSDictionary* dict = [self getResultImages];
    
    NSArray* imgArr = [dict objectForKey:@"images"];
    NSArray* delayTimeArr = [dict objectForKey:@"delayTimes"];
    
    if(imgArr == nil || delayTimeArr == nil || imgArr.count == 0 || imgArr.count != delayTimeArr.count)
    {
        CGE_NSLog(@"Save as gif failed!...\n");
        return NO;
    }

    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifUrl,
                                                                        kUTTypeGIF, imgArr.count, nil);
    
    if(loopCount < 0)
        loopCount = 0;
    
    NSDictionary *gifProperties = @{ (__bridge id)kCGImagePropertyGIFDictionary: @{
                                             (__bridge id)kCGImagePropertyGIFLoopCount: @(loopCount), // 0 means loop forever
                                             }
                                     };
    
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
    
    for(int i = 0; i < imgArr.count; ++i)
    {
        UIImage* img = [imgArr objectAtIndex:i];
        float delay = [[delayTimeArr objectAtIndex:i] floatValue];
        
        NSDictionary* frameDict = @{
                                    (__bridge id)kCGImagePropertyGIFDictionary: @{
                                            (__bridge id)kCGImagePropertyGIFDelayTime: @(delay)
                                            }
                                    };
        
        CGImageDestinationAddImage(destination, img.CGImage, (__bridge CFDictionaryRef)frameDict);
        
    }
    
    BOOL status = CGImageDestinationFinalize(destination);
    
    CFRelease(destination);
    
    if(!status)
    {
        CGE_NSLog(@"failed to finalize image destination");
    }
    
    return status;
}

- (BOOL)startAnimation
{
    if(_vecImageFrames.empty())
        return NO;
    
    [self stopAnimation];
    
    _currentStillTime = 0.0;
    _lastFrameTime = CFAbsoluteTimeGetCurrent();
    _currentImageIndex = 0;
    _lastImageFrame = &_vecImageFrames[0];
    
    _animTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(animationLoop) userInfo:nil repeats:YES];
    
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        [self flushFrameWithTexture:_vecImageFrames[0].imageTexture];
    }];
    
    [self.glkView display];
    
    return YES;
}

- (void)stopAnimation
{
    if(_animTimer)
    {
        [_animTimer invalidate];
        _animTimer = nil;
    }
    
    _lastImageFrame = nullptr;
}

- (CGE_IMAGEVIEW_IMAGEHANDLER_IOS*)getHandlerIOS
{
    return (CGE_IMAGEVIEW_IMAGEHANDLER_IOS*)[self _getHandler];
}

- (void)flushFrameWithTexture: (GLuint)tex
{
    CGE_IMAGEVIEW_IMAGEHANDLER_IOS* handler = [self getHandlerIOS];
    if(handler == nil)
        return;
    
    handler->setAsTarget();
    _frameDrawer->drawTexture(tex);
    handler->processingFilters();
}

- (void)animationLoop
{
    if(_animTimer == nil || _vecImageFrames.empty() || _lastImageFrame == nullptr)
        return;
    
    double currentTime = CFAbsoluteTimeGetCurrent();
    _currentStillTime += currentTime - _lastFrameTime;
    
    if(_currentStillTime > _lastImageFrame->delayTime)
    {
        _currentStillTime = 0.0f;
        ++_currentImageIndex;
        _currentImageIndex %= _vecImageFrames.size();
        _lastImageFrame = &_vecImageFrames[_currentImageIndex];
        
        [self.sharedContext syncProcessingQueue:^{
            
            [self.sharedContext makeCurrent];
            [self flushFrameWithTexture:_lastImageFrame->imageTexture];
            [self.glkView display];
        }];
    }
    
    _lastFrameTime = currentTime;
}

- (BOOL)jumpToFrame:(int)frameIndex
{
    if(_vecImageFrames.empty() || frameIndex >= _vecImageFrames.size())
        return NO;
    
    _currentImageIndex = frameIndex;
    _currentStillTime = 0;

    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        ImageFrame& frame = _vecImageFrames[_currentImageIndex];
        [self flushFrameWithTexture:frame.imageTexture];
    }];
    
    return YES;
}

- (BOOL)setFilterWithConfig:(const char *)config
{
    CGE_IMAGEVIEW_IMAGEHANDLER_IOS* handler = [self getHandlerIOS];
    
    if(handler->reversionEnabled())
    {
        return [super setFilterWithConfig:config];
    }
    
    if(handler == nullptr)
        return NO;
    
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
        handler->clearImageFilters();
        
        if(config == nullptr || *config == '\0')
        {
            return ;
        }
        
        CGEMutipleEffectFilter* filters = (CGEMutipleEffectFilter*)cgeCreateMultipleFilterByConfig(config, 1.0f);
        
        if(filters == nullptr)
        {
            CGE_NSLog(@"Invalid Filter Config: %s", config);
            return ;
        }
        
        handler->addImageFilter(filters);
    }];
    
    return handler->getFilterNum() != 0;
}

- (void)setFilterIntensity:(float)value
{
    CGE_IMAGEVIEW_IMAGEHANDLER_IOS* handler = [self getHandlerIOS];
    
    if(handler->reversionEnabled())
    {
        [super setFilterIntensity:value];
    }
    
    if(handler == nullptr || handler->getFilterNum() == 0)
        return ;
    
    [self setCurrentIntensity:value];
    
    [self.sharedContext asyncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        auto&& filters = handler->peekFilters();
        for(auto* filter : filters)
        {
            filter->setIntensity(self.currentIntensity);
        }
    }];
}

- (NSDictionary*)getResultImages
{
    if(_vecImageFrames.empty())
        return nil;
    
    __block NSMutableArray* imgArr = [[NSMutableArray alloc] initWithCapacity:_vecImageFrames.size()];
    __block NSMutableArray* timeDelayArr = [[NSMutableArray alloc] initWithCapacity:_vecImageFrames.size()];
    
    [self.sharedContext syncProcessingQueue:^{
        [self.sharedContext makeCurrent];
        
        CGE_IMAGEVIEW_IMAGEHANDLER_IOS* handler = [self getHandlerIOS];
        
        bool bufferEnabled = handler->isImageBufferEnabled();
        
        if(!bufferEnabled)
            handler->enableImageBuffer(true);
        
        for(auto& imageFrame : _vecImageFrames)
        {
            [timeDelayArr addObject:@(imageFrame.delayTime)];
            
            handler->setAsTarget();
            _frameDrawer->drawTexture(imageFrame.imageTexture);
            handler->processingFilters();
            UIImage* img = handler->getResultUIImage();
            [imgArr addObject:img];
        }
        
        if(!bufferEnabled)
            handler->enableImageBuffer(false);

    }];
    
    return @{@"images" : imgArr, @"delayTimes" : timeDelayArr};
}

@end
