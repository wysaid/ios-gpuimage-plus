/*
 * cgeCVUtilTexture.h
 *
 *  Created on: 2015-11-6
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */


#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <CoreVideo/CoreVideo.h>

@interface CGECVUtilTexture : NSObject

@property(nonatomic, readonly)int textureWidth;
@property(nonatomic, readonly)int textureHeight;

- (id)initWithSize:(int)width height:(int)height;
- (id)initWithSize:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPool;
- (void)clear;

- (CVPixelBufferRef)pixelBufferRef;
- (CVOpenGLESTextureRef)textureRef;
- (CVOpenGLESTextureCacheRef)textureCacheRef;
- (GLenum)textureTarget;
- (GLuint)textureID;

////////////////////////

//+ (BOOL)supportsFastTextureUpload;
//
//+ (NSInteger)maximumTextureSizeForThisDevice;
//+ (NSInteger)maximumTextureUnitsForThisDevice;
//
//+ (BOOL)deviceSupportsOpenGLESExtension:(NSString *)extension;
//+ (BOOL)deviceSupportsRedTextures;
//+ (BOOL)deviceSupportsFramebufferReads;

////////////////////////

//便捷方法， 生成较常用的 pixelBufferPoolRef
//此处生成的 CVPixelBufferPoolRef 需要手动调用下方的 release 方法来释放
+ (CVPixelBufferPoolRef)makePixelBufferPoolRef:(int)width height:(int)height;
+ (void)releasePixelBufferPoolRef:(CVPixelBufferPoolRef)bufferPoolRef;

//当 bufferPoolRef 为 nil 时， 将额外创建新的bufferPool.
+ (instancetype)makeCVTexture:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPoolRef;

@end

////////////////////////////////////////////////

typedef struct CGECVBufferData
{
    void* data;
    int width, height;
    int bytesPerRow; //May not be the same with (width * channels)
    int channels;  //'channels' is always 4 for now.
    
}CGECVBufferData;

@interface CGECVUtilTextureWithFramebuffer : CGECVUtilTexture

- (GLuint)framebuffer;

- (void)bindTextureFramebuffer;

//'lockFlag' = 1 (kCVPixelBufferLock_ReadOnly) for readOnly, 0 for read&write.
//glFinish should be called if any gl functions are not finished.
- (CGECVBufferData)mapBuffer:(CVPixelBufferLockFlags)lockFlag;
- (void)unmapBuffer:(CVPixelBufferLockFlags)lockFlag;

+ (instancetype)makeCVTexture:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPoolRef;

@end