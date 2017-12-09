/*
 * cgeFrameRenderer.mm
 *
 *  Created on: 2015-10-12
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeFrameRenderer.h"
#import "cgeVideoHandlerCV.h"
#import "cgeTextureUtils.h"
#import "cgeMultipleEffects.h"
#import "cgeUtilFunctions.h"

using namespace CGE;

CGE_UNEXPECTED_ERR_MSG
(
 static int sRendererCount = 0;
 )

@interface CGEFrameRenderer()
{
    CGEVideoHandlerCV* _videoHandler;
    TextureDrawer* _textureDrawer;
    float _drawerFlipScaleX, _drawerFlipScaleY;
}

@end

@implementation CGEFrameRenderer

- (id)initWithContext :(CGESharedGLContext*)sharedContext
{
    self = [super init];
    
    if(self != nil)
    {
        _sharedContext = [CGESharedGLContext createSharedContext:sharedContext];
        
        _drawerFlipScaleX = 1.0f;
        _drawerFlipScaleY = -1.0f;
        _renderLock = [[NSLock alloc] init];
        _isUsingMask = NO;
        
        [self setupRenderer];
        
        CGE_UNEXPECTED_ERR_MSG
        (
         CGE_LOG_KEEP("FrameRenderer create, total: %d\n", ++sRendererCount);
         )
    }
    
    return self;
}

- (void)dealloc
{
    [self clear];
    
    CGE_UNEXPECTED_ERR_MSG
    (
     CGE_LOG_KEEP("FrameRenderer release, remain: %d\n", --sRendererCount);
     )
}

- (void)clear
{
    if(_sharedContext != nil)
    {
        [_sharedContext syncProcessingQueue:^{
            [_sharedContext makeCurrent];
            
            [_renderLock lock];
            delete _videoHandler;
            _videoHandler = nullptr;
            delete _textureDrawer;
            _textureDrawer = nullptr;
            [_renderLock unlock];
        }];
        
        
        _sharedContext = nil;
    }
    
    _renderLock = nil;
}

- (BOOL)setupRenderer
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        _videoHandler = new CGEVideoHandlerCV();
        if(!_videoHandler->initHandler())
        {
            delete _videoHandler;
            _videoHandler = nullptr;
        }
        
        _textureDrawer = TextureDrawer::create();
        CGEAssert(_textureDrawer != nullptr);
        
        _textureDrawer->setFlipScale(_drawerFlipScaleX, _drawerFlipScaleY);
    }];
    
    return _videoHandler != nullptr;
}

- (void)drawResult
{
    [_renderLock lock];
    CGE_NSLog_Code
    (
     if(_videoHandler->getTargetTextureID() == 0)
     {
         CGE_NSLog(@"❌❌Invalid Texture ID !!");
     }
    );
    _textureDrawer->drawTexture(_videoHandler->getTargetTextureID());
    [_renderLock unlock];
}

- (void)fastDrawResult
{
    _textureDrawer->drawTexture(_videoHandler->getTargetTextureID());
}

- (void)drawTexture:(GLuint)texID
{
    _textureDrawer->drawTexture(texID);
}

- (void)setYUVDrawerFlipScale:(float)flipScaleX flipScaleY:(float)flipScaleY
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
//        [_renderLock lock];
        auto* drawer = _videoHandler->getYUVDrawer();
        drawer->setFlipScale(flipScaleX, flipScaleY);
//        [_renderLock unlock];

    }];
}

- (void)setYUVDrawerRotation:(float)rotation
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
//        [_renderLock lock];
        auto* drawer = _videoHandler->getYUVDrawer();
        drawer->setRotation(rotation);
//        [_renderLock unlock];

    }];
}

- (void)setResultDrawerFlipScale:(float)flipScaleX flipScaleY:(float)flipScaleY
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        _textureDrawer->setFlipScale(flipScaleX, flipScaleY);
    }];
}

- (void)setResultDrawerRotation:(float)rotation
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        _textureDrawer->setRotation(rotation);
    }];
}

- (void)setReverseTargetSize:(BOOL)reverseTargetSize
{
    _reverseTargetSize = reverseTargetSize;

    if(_videoHandler)
        _videoHandler->setReverseTargetSize(_reverseTargetSize);
}

- (void*)getVideoHandler
{
    return _videoHandler;
}

- (GLuint)getResultTexture
{
    CGE_NSLog_Code
    (
     if(_videoHandler->getTargetTextureID() == 0)
     {
         CGE_NSLog(@"❌❌Invalid Texture ID !");
     }
    );
    
    return _videoHandler->getTargetTextureID();
}

- (void)replaceYUVDrawer:(void *)drawer deleteOlder:(BOOL)deleteOlder
{
    _videoHandler->replaceYUVDrawer((TextureDrawerYUV*)drawer, deleteOlder);
}

- (void)setFilterWithConfig :(const char*) config
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        _videoHandler->clearImageFilters(true);
        if(config == nullptr || *config == '\0')
            return;
        
        CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
        filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
        if(!filter->initWithEffectString(config))
        {
            delete filter;
            filter = nullptr;
            CGE_LOG_ERROR("setFilterWithConfig failed!");
        }
        
        _videoHandler->addImageFilter(filter);
    }];
}

- (void)setFilterIntensity :(float)value
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        auto&& filters = _videoHandler->peekFilters();
        for(auto* filter : filters)
        {
            filter->setIntensity(value);
        }
    }];
}

- (void)setFilterWithAddress :(void*)filter
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        _videoHandler->clearImageFilters(true);
        if(filter != nullptr)
        {
            _videoHandler->addImageFilter((CGE::CGEImageFilterInterfaceAbstract*)filter);
        }
    }];
}

- (void)_setMaskTexture :(GLuint)maskTexture textureAspectRatio:(float)aspectRatio
{
    if(maskTexture == 0)
    {
        if(_isUsingMask || _textureDrawer == nullptr)
        {
            [_renderLock lock];
            _isUsingMask = NO;
            delete _textureDrawer;
            _textureDrawer = TextureDrawer::create();
            _textureDrawer->setFlipScale(_drawerFlipScaleX, _drawerFlipScaleY);
            [_renderLock unlock];
        }
        return;
    }
    
    _isUsingMask = YES;
    
    auto* drawer = TextureDrawerWithMask::create();
    if(drawer == nullptr)
    {
        CGE_LOG_ERROR("init mask drawer failed!");
        return;
    }
    
    [_renderLock lock];
    delete _textureDrawer;
    _textureDrawer = drawer;
    drawer->setMaskTexture(maskTexture);
    drawer->setMaskFlipScale(1.0f, -1.0f);
    [_renderLock unlock];
    [self setMaskTextureRatio:aspectRatio];
}

- (void)setMaskTexture :(GLuint)maskTexture textureAspectRatio:(float)aspectRatio
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        [self _setMaskTexture:maskTexture textureAspectRatio:aspectRatio];
    }];
}

- (void)setMaskTextureRatio:(float)aspectRatio
{
    if(aspectRatio > 1.0f)
    {
        _textureDrawer->setFlipScale(_drawerFlipScaleX / aspectRatio, _drawerFlipScaleY);
    }
    else
    {
        _textureDrawer->setFlipScale(_drawerFlipScaleX, _drawerFlipScaleY * aspectRatio);
    }
}

- (void)setMaskUIImage:(UIImage *)image
{
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        CGETextureInfo info = cgeUIImage2Texture(image);

        float aspectRatio = info.name == 0 ? 1.0f : info.width / (float)info.height;
        [self _setMaskTexture:info.name textureAspectRatio:aspectRatio];
    }];
}

- (void)takeShot :(void (^)(UIImage*))block
{
    CGE_NSAssert(block != nil, @"takeshot: block should not be nil!");
    
    if(_sharedContext == nil || _videoHandler == nil) {
        CGE_NSLog(@"Err: taking shot after release!!\n");
        block(nil);
    }
    
    [_sharedContext asyncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        if(_videoHandler == nullptr) {
            CGE_NSLog(@"video handler not initialized!!\n");
            block(nil);
            return ;
        }
        
        [_renderLock lock];
        const CGESizei& sz = _videoHandler->getOutputFBOSize();
        void* buffer = malloc(sz.width * sz.height * 4);
        _videoHandler->getOutputBufferData(buffer, CGE_FORMAT_RGBA_INT8);
        UIImage* img = cgeCreateUIImageWithBufferRGBA(buffer, sz.width, sz.height, 8, sz.width * 4);
        free(buffer);
        block(img);
        [_renderLock unlock];
    }];
}

@end
