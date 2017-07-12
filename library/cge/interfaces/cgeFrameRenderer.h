/*
 * cgeFrameRenderer.h
 *
 *  Created on: 2015-10-12
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "cgeSharedGLContext.h"

#define CGE_FRAMERENDERER_VIDEOHANDLER_TYPE CGEVideoHandlerCV

@protocol CGEFrameUpdateDelegate <NSObject>

@required
- (void)frameUpdated;

@end

@protocol CGEFrameProcessingDelegate <NSObject>

@required

// The return value marks if you modified the imageBuffer. (Faster when return NO)
// 返回值表示是否对imageBuffer进行了修改
- (BOOL)processingHandleBuffer :(CVImageBufferRef)imageBuffer;

@optional

- (BOOL)bufferRequestRGBA;

- (void)drawProcResults:(void*)handler;

- (void)setSharedContext:(CGESharedGLContext*)context;

- (CMSampleBufferRef)processingAudioBuffer:(CMSampleBufferRef)audioBuffer;

- (void)processingAudioPCMBuffer:(short*)pcmBuffer sampleFrames:(int)frames;

@end

//use for extra rendering
@protocol CGEFrameExtraRenderingDelegate <NSObject>

@required

- (void)extraDrawFrame:(void*)handler;

@optional

- (void)setSharedContext:(CGESharedGLContext*)context;

@end

@interface CGEFrameRenderer : NSObject

@property(nonatomic, readonly) BOOL isUsingMask;

@property(nonatomic, readonly) CGESharedGLContext* sharedContext;
@property(nonatomic, readonly) NSLock* renderLock;
@property(nonatomic) BOOL reverseTargetSize;

#pragma mark - 初始化相关

- (id)initWithContext :(CGESharedGLContext*)sharedContext;

// 手动调用释放内存等
- (void)clear;

// 渲染当前帧
- (void)drawResult;

// 与drawResult功能相同, 但是将不加锁也不检查错误.
- (void)fastDrawResult;
- (void)drawTexture:(GLuint)texID; //辅助功能

#pragma mark - 滤镜相关接口

- (void)setFilterWithConfig :(const char*) config;
- (void)setFilterIntensity :(float)value;
- (void)setFilterWithAddress :(void*)filter;

#pragma mark - mask设定接口

- (void)setMaskTexture :(GLuint)maskTexture textureAspectRatio:(float)aspectRatio;
- (void)setMaskUIImage :(UIImage*)image;
- (void)setMaskTextureRatio:(float)aspectRatio;

#pragma mark - 辅助方法
- (void)setYUVDrawerFlipScale:(float)flipScaleX flipScaleY:(float)flipScaleY;
- (void)setYUVDrawerRotation:(float)rotation;

- (void)setResultDrawerFlipScale:(float)flipScaleX flipScaleY:(float)flipScaleY;
- (void)setResultDrawerRotation:(float)rotation;

- (void*)getVideoHandler;
- (GLuint)getResultTexture;

//特殊用法, 慎用(使用自定义的YUVDrawer替换默认内建YUVDrawer, 改变默认yuv渲染, drawer类型: TextureDrawerYUV)
//如果未对取用的yuvDrawer进行保存, 那么 deleteOlder 参数应该为 YES
- (void)replaceYUVDrawer:(void*)drawer deleteOlder:(BOOL)deleteOlder;

#pragma mark - 其他接口

//截图
- (void)takeShot :(void (^)(UIImage*))block;

@end
