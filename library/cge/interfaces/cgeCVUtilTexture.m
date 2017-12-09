/*
 * cgeCVUtilTexture.m
 *
 *  Created on: 2015-11-6
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeCVUtilTexture.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
//#import "cgeSharedGLContext.h"


@interface CGECVUtilTexture()
{
    CVPixelBufferRef _pixelBufferRef;
    CVOpenGLESTextureRef _textureRef;
    CVOpenGLESTextureCacheRef _textureCacheRef;
    GLuint _textureID;
    GLenum _textureTarget;
}

@end

@implementation CGECVUtilTexture

- (id)initWithSize:(int)width height:(int)height
{
    return [self initWithSize:width height:height bufferPool:nil];
}

- (id)initWithSize:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPool
{
    self = [super init];
    if(![self setupWithSize:width height:height bufferPool:bufferPool])
    {
        [self clear];
        self = nil;
    }
    
    return self;
}

- (void)dealloc
{
    [self clear];
}

- (void)clear
{
    if(_pixelBufferRef != nil)
    {
        CVPixelBufferRelease(_pixelBufferRef);
        _pixelBufferRef = nil;
    }
    
    if(_textureRef != nil)
    {
        CFRelease(_textureRef);
        _textureRef = nil;
    }
    
    if(_textureCacheRef != nil)
    {
        CVOpenGLESTextureCacheFlush(_textureCacheRef, 0);
        CFRelease(_textureCacheRef);
        _textureCacheRef = nil;
    }
    
    _textureID = 0;
}

- (BOOL)setupWithSize:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPool
{
    _textureWidth = width;
    _textureHeight = height;
    
    CVPixelBufferPoolRef newBufferPool = (bufferPool != nil) ? bufferPool : [CGECVUtilTexture makePixelBufferPoolRef:width height:height];
    
    if(newBufferPool == nil)
        return NO;
    
    CVReturn ret = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, newBufferPool, &_pixelBufferRef);

    if(newBufferPool != bufferPool)
    {
        [CGECVUtilTexture releasePixelBufferPoolRef:newBufferPool];
        newBufferPool = nil;        
    }
    
    if (kCVReturnSuccess != ret)
    {
        return NO;
    }
    
    CVEAGLContext context = [EAGLContext currentContext];
    ret = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &_textureCacheRef);
    
    if (kCVReturnSuccess != ret)
    {
        return NO;
    }
    
    ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _textureCacheRef,
                                                       _pixelBufferRef, NULL,
                                                       GL_TEXTURE_2D, GL_RGBA,
                                                       width, height,
                                                       GL_BGRA, GL_UNSIGNED_BYTE, 0,
                                                       &_textureRef);
    NSCAssert(kCVReturnSuccess == ret, @"CVOpenGLESTextureCacheCreateTextureFromImage Failed!");
    if (kCVReturnSuccess != ret)
    {
        return NO;
    }

    _textureID = CVOpenGLESTextureGetName(_textureRef);
    _textureTarget = CVOpenGLESTextureGetTarget(_textureRef);
    
    glBindTexture(_textureTarget, _textureID);
//    glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//    glTexParameteri(_textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    return YES;
}

- (CVPixelBufferRef)pixelBufferRef
{
    return _pixelBufferRef;
}

- (CVOpenGLESTextureRef)textureRef
{
    return _textureRef;
}

- (CVOpenGLESTextureCacheRef)textureCacheRef
{
    return _textureCacheRef;
}

- (GLenum)textureTarget
{
    return _textureTarget;
}

- (GLuint)textureID
{
    return _textureID;
}

/////////////////////////////////////////////

//+ (BOOL)supportsFastTextureUpload
//{
//#if TARGET_IPHONE_SIMULATOR
//    return NO;
//#else
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
//    return (CVOpenGLESTextureCacheCreate != NULL);
//#pragma clang diagnostic pop
//#endif
//}


//+ (NSInteger)maximumTextureSizeForThisDevice
//{
//    static dispatch_once_t pred;
//    static GLint maxTextureSize = 0;
//    
//    dispatch_once(&pred, ^{
//        [CGESharedGLContext useGlobalGLContext];
//        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
//    });
//    
//    
//    return (NSInteger)maxTextureSize;
//}

//+ (NSInteger)maximumTextureUnitsForThisDevice
//{
//    GLint maxTextureUnits;
//    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &maxTextureUnits);
//    return (NSInteger)maxTextureUnits;
//}
//
//+ (BOOL)deviceSupportsOpenGLESExtension:(NSString *)extension
//{
//    static dispatch_once_t pred;
//    static NSArray *extensionNames = nil;
//    
//    // Cache extensions for later quick reference, since this won't change for a given device
//    dispatch_once(&pred, ^{
//        [CGESharedGLContext useGlobalGLContext];
//        NSString *extensionsString = [NSString stringWithCString:(const char *)glGetString(GL_EXTENSIONS) encoding:NSASCIIStringEncoding];
//        extensionNames = [extensionsString componentsSeparatedByString:@" "];
//    });
//    
//    return [extensionNames containsObject:extension];
//}


//+ (BOOL)deviceSupportsRedTextures
//{
//    static dispatch_once_t pred;
//    static BOOL supportsRedTextures = NO;
//    
//    dispatch_once(&pred, ^{
//        supportsRedTextures = [self deviceSupportsOpenGLESExtension:@"GL_EXT_texture_rg"];
//    });
//    
//    return supportsRedTextures;
//}
//
//+ (BOOL)deviceSupportsFramebufferReads
//{
//    static dispatch_once_t pred;
//    static BOOL supportsFramebufferReads = NO;
//    
//    dispatch_once(&pred, ^{
//        supportsFramebufferReads = [self deviceSupportsOpenGLESExtension:@"GL_EXT_shader_framebuffer_fetch"];
//    });
//    
//    return supportsFramebufferReads;
//}

+ (CVPixelBufferPoolRef)makePixelBufferPoolRef:(int)width height:(int)height
{
    
    // code from http://stackoverflow.com/questions/11607753/cvopenglestexturecachecreatetexturefromimage-on-ipad2-is-too-slow-it-needs-almo
    NSDictionary *attributes = @{(NSString *)kCVPixelBufferWidthKey:@(width),
                                 (NSString *)kCVPixelBufferHeightKey:@(height),
                                 (NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA),
                                 (NSString *)kCVPixelBufferCGImageCompatibilityKey:@YES,
                                 (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey:@YES,
                                 (NSString *)kCVPixelBufferOpenGLESCompatibilityKey:@YES,
                                 // Provide an empty dictionary to use default IOSurface options
                                 (NSString *)kCVPixelBufferIOSurfacePropertiesKey:@{}
                                 //    attributes[(NSString *)kCVPixelBufferIOSurfacePropertiesKey] = @{@"IOSurfaceOpenGLESFBOCompatibility":@YES, @"IOSurfaceOpenGLESTextureCompatibility":@YES};
                                 };
    
    
    CVPixelBufferPoolRef bufferPool = NULL;
    CVReturn ret = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)attributes, &bufferPool);
    CGE_NSAssert(kCVReturnSuccess == ret, @"CVPixelBufferPoolCreate Failed!");
    if (kCVReturnSuccess != ret)
    {
        return nil;
    }

    return bufferPool;
}

+ (void)releasePixelBufferPoolRef:(CVPixelBufferPoolRef)bufferPoolRef
{
    CGE_NSAssert(bufferPoolRef != nil, @"CGECVUtilTexture: buffer pool should not be nil!");
    CVPixelBufferPoolRelease(bufferPoolRef);
}

+ (instancetype)makeCVTexture:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPoolRef
{
    CGECVUtilTexture* tex = [[CGECVUtilTexture alloc] initWithSize:width height:height bufferPool:bufferPoolRef];
    
    if(tex && tex.textureID == 0)
    {
        [tex clear];
        tex = nil;
    }
    
    return tex;
}

@end

@interface CGECVUtilTextureWithFramebuffer()
{
    GLuint _framebufferID;
}

@end

@implementation CGECVUtilTextureWithFramebuffer

- (id)initWithSize:(int)width height:(int)height
{
    return [self initWithSize:width height:height bufferPool:nil];
}

- (id)initWithSize:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPool
{
    self = [super init];
    if([self setupWithSize:width height:height bufferPool:bufferPool])
    {
        glGenFramebuffers(1, &_framebufferID);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebufferID);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, self.textureTarget, self.textureID, 0);
        
#if defined(DEBUG) || defined(_DEBUG)
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        CGE_NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"CGECVUtilTextureWithFramebuffer - initWithSize: Incomplete FBO: %x\n", status);
        
#endif
        
    }
    else
    {
        [self clear];
        self = nil;
    }
    
    return self;
}

- (void)clear
{
    [super clear];
    
    if(_framebufferID != 0)
    {
        glDeleteFramebuffers(1, &_framebufferID);
        _framebufferID = 0;
    }
}

- (GLuint)framebuffer
{
    return _framebufferID;
}

- (void)bindTextureFramebuffer
{
    glBindFramebuffer(GL_FRAMEBUFFER, _framebufferID);
    glViewport(0, 0, self.textureWidth, self.textureHeight);
}

- (CGECVBufferData)mapBuffer:(CVPixelBufferLockFlags)lockFlag
{
    CGECVBufferData data = { nil };
    
    if(_framebufferID != 0 && self.textureID != 0)
    {
        CVReturn ret = CVPixelBufferLockBaseAddress(self.pixelBufferRef, lockFlag);
        if(ret == kCVReturnSuccess)
        {
            data.width = (int)CVPixelBufferGetWidth(self.pixelBufferRef);
            data.height = (int)CVPixelBufferGetHeight(self.pixelBufferRef);
            data.bytesPerRow = (int)CVPixelBufferGetBytesPerRow(self.pixelBufferRef);
            data.channels = 4;
            data.data = CVPixelBufferGetBaseAddress(self.pixelBufferRef);
        }
        else
        {
            CGE_NSLog(@"CGECVUtilTextureWithFramebuffer : Error mapping buffer %d", ret);
        }
    }
    
    return data;
}

- (void)unmapBuffer:(CVPixelBufferLockFlags)lockFlag
{
    if(_framebufferID != 0 && self.textureID != 0)
    {
        CVReturn ret = CVPixelBufferUnlockBaseAddress(self.pixelBufferRef, lockFlag);
        if(ret != kCVReturnSuccess)
        {
            CGE_NSLog(@"CGECVUtilTextureWithFramebuffer : Error unmapping buffer %d", ret);
        }
    }
}

+ (instancetype)makeCVTexture:(int)width height:(int)height bufferPool:(CVPixelBufferPoolRef)bufferPoolRef
{
    CGECVUtilTextureWithFramebuffer* tex = [[CGECVUtilTextureWithFramebuffer alloc] initWithSize:width height:height bufferPool:bufferPoolRef];
    
    if(tex && tex.textureID == 0)
    {
        [tex clear];
        tex = nil;
    }
    
    return tex;
}


@end
