/*
 * cgeImageViewHandler.m
 *
 *  Created on: 2015-11-18
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeImageViewHandler.h"
#import "cgeImageHandlerIOS.h"
#import "cgeUtilFunctions.h"
#include "cgeMultipleEffects.h"
#include "cgeTextureUtils.h"

using namespace CGE;

@interface CGEImageViewHandler()<GLKViewDelegate>
{
    CGEImageHandlerIOS* _imageHandler;
    CGEImageViewDisplayMode _displayMode;
    CGRect _viewArea;
    BOOL _shouldValidateViewArea;
    dispatch_semaphore_t _intensityAdjustSemaphore;
}

@end

@implementation CGEImageViewHandler

- (id)initWithGLKView:(GLKView *)glkView
{
    self = [super init];
    
    if(self != nil)
    {
        [self setGlkView:glkView];
        [self _setupView];
    }
    
    return self;
}

- (id)initWithGLKView:(GLKView *)glkView withImage:(UIImage *)image
{
    self = [self initWithGLKView:glkView];
    
    if(self && image)
    {
        [self setUIImage:image];
    }
    
    return self;
}

- (void)_setupView
{
    if(_sharedContext != nil)
    {
        CGE_NSLog(@"Invalid call to setupView!");
        return;
    }
    
    _sharedContext = [CGESharedGLContext createGlobalSharedContext];
    _intensityAdjustSemaphore = dispatch_semaphore_create(2);
    _displayMode = CGEImageViewDisplayModeDefault;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        _imageHandler = new CGEImageHandlerIOS;
        TextureDrawer* drawer = _imageHandler->getResultDrawer();
        CGEAssert(drawer != nullptr);
        drawer->setFlipScale(1.0f, -1.0f);
    }];
}

- (void)dealloc
{
    [self clear];
}

- (void)clear
{
    dispatch_semaphore_wait(_intensityAdjustSemaphore, DISPATCH_TIME_FOREVER);
    
    if(_sharedContext != nil)
    {
        [_sharedContext syncProcessingQueue:^{
            [_sharedContext makeCurrent];
            delete _imageHandler;
            _imageHandler = nullptr;
        }];
        _sharedContext = nil;
        [EAGLContext setCurrentContext:nil];
    }
    
    _glkView = nil;
    
    dispatch_semaphore_signal(_intensityAdjustSemaphore);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [_glkView bindDrawable];
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    if(_imageHandler == nullptr || _imageHandler->getTargetTextureID() == 0)
        return;
    
    if(_displayMode != CGEImageViewDisplayModeScaleToFill)
    {
        if(_shouldValidateViewArea)
        {
            [self _updateViewArea];
        }
        
        glViewport(_viewArea.origin.x, _viewArea.origin.y, _viewArea.size.width, _viewArea.size.height);
    }
    
    _imageHandler->drawResult();

}

- (void)setGlkView:(GLKView*)glkView
{
    _glkView = glkView;
    [_glkView setDelegate:self];
    [_glkView setDrawableColorFormat:GLKViewDrawableColorFormatRGBA8888];
    [_glkView setContext:[[CGESharedGLContext globalGLContext] context]];
    [_glkView setEnableSetNeedsDisplay:NO];
    [_glkView setBackgroundColor:[UIColor clearColor]];
}

- (BOOL)setFilterWithConfig:(const char *)config
{
    if(_imageHandler == nullptr)
        return NO;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        _imageHandler->clearImageFilters();
        _imageHandler->revertToKeptResult();
        
        if(config == nullptr || *config == '\0')
        {
            glFinish();
            return ;
        }
        
        CGEMutipleEffectFilter* filters = (CGEMutipleEffectFilter*)cgeCreateMultipleFilterByConfig(config, 1.0f);
        if(filters == nullptr)
        {
            CGE_NSLog(@"Invalid Filter Config: %s", config);
            return ;
        }
        
        _imageHandler->addImageFilter(filters);
        _imageHandler->processingFilters();
    }];
    
    [_glkView display];
    return _imageHandler->getFilterNum() != 0;
}

- (BOOL)setFilter :(void*)filter
{
    if(_imageHandler == nullptr)
        return NO;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        _imageHandler->clearImageFilters();
        _imageHandler->revertToKeptResult();
        
        if(filter == nullptr)
        {
            glFinish();
            return ;
        }
        
        _imageHandler->addImageFilter((CGEImageFilterInterfaceAbstract*)filter);
        _imageHandler->processingFilters();
    }];
    
    [_glkView display];
    
    return _imageHandler->getFilterNum() != 0;
}

- (BOOL)setFilterWithWrapper:(void *)filter
{
    if(_imageHandler == nullptr)
        return NO;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        _imageHandler->clearImageFilters();
        _imageHandler->revertToKeptResult();
        
        if(filter == nullptr)
        {
            glFinish();
            return ;
        }
        
        CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
        filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
        filter->initCustomize();
        filter->addFilter((CGEImageFilterInterface*)filter);
        
        _imageHandler->addImageFilter((CGEImageFilterInterfaceAbstract*)filter);
        _imageHandler->processingFilters();
    }];
    
    [_glkView display];
    
    return _imageHandler->getFilterNum() != 0;
}

- (void)flush
{
    if(_imageHandler == nullptr)
        return ;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        _imageHandler->revertToKeptResult();
        _imageHandler->processingFilters();
    }];
    
    [_glkView display];
}

- (void)setFilterIntensity:(float)value
{
    if(_imageHandler == nullptr || _imageHandler->getFilterNum() == 0)
        return ;
    
    _currentIntensity = value;
    
    if(dispatch_semaphore_wait(_intensityAdjustSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        CGE_LOG_INFO("滑动过频， 丢弃中间帧...\n");
        return;
    }
    
    [_sharedContext asyncProcessingQueue:^{
        [_sharedContext makeCurrent];
        auto&& filters = _imageHandler->peekFilters();
        for(auto* filter : filters)
        {
            filter->setIntensity(_currentIntensity);
        }
        
        if(!filters.empty())
        {
            _imageHandler->revertToKeptResult();
            _imageHandler->processingFilters();
            [_glkView display];
        }
        
        dispatch_semaphore_signal(_intensityAdjustSemaphore);
    }];
}

- (BOOL)setUIImage:(UIImage *)image
{
    if(image == nil)
        return NO;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        if(_imageHandler == nullptr)
        {
            CGE_NSLog(@"❌handler is null!!");
            return;
        }
        
        if(!_imageHandler->initWithUIImage(image, true, true))
        {
            delete _imageHandler;
            _imageHandler = nullptr;
            CGE_NSLog(@"❌初始化Image Handler失败!\n");
            return ;
        }
    }];
    
    if(_imageHandler == nullptr)
        return NO;
    
    _imageSize = image.size;
    
    if(_displayMode != CGEImageViewDisplayModeScaleToFill)
        [self _updateViewArea];
    
    [_glkView display];
    
    return YES;
}

- (UIImage*)resultImage
{
    if(_imageHandler == nullptr || _imageHandler->getTargetTextureID() == 0)
        return nil;
    
    __block UIImage* resultImage = nil;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        resultImage = _imageHandler->getResultUIImage();
    }];
    
    return resultImage;
}

- (void)_updateViewArea
{
    float viewWidth = _glkView.drawableWidth, viewHeight = _glkView.drawableHeight;
    CGSize sz = self.imageSize;
    float scaling;
    
    scaling = sz.width / sz.height;
    
    float viewRatio = viewWidth / viewHeight;
    float s = scaling / viewRatio;
    
    float w, h;
    
    switch (_displayMode)
    {
        case CGEImageViewDisplayModeAspectFill:
        {
            //保持比例撑满全部view(内容大于view)
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
        }
            break;
        case CGEImageViewDisplayModeAspectFit:
        {
            //保持比例撑满全部view(内容小于view)
            if(s < 1.0)
            {
                w = (int)(viewHeight * scaling);
                h = viewHeight;
            }
            else
            {
                w = viewWidth;
                h = (int)(viewWidth / scaling);
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
    _shouldValidateViewArea = NO;
}

- (void)setViewDisplayMode :(CGEImageViewDisplayMode)mode
{
    _displayMode = mode;
    if(_displayMode != CGEImageViewDisplayModeScaleToFill)
    {
        _shouldValidateViewArea = YES;
    }
    
    [_glkView display];
}

- (void*)_getHandler
{
    return _imageHandler;
}

@end
