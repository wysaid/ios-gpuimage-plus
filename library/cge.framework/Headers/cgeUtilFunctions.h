/*
 * cgeUtilFunctions.h
 *
 *  Created on: 2015-7-10
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */


// Provide some useful functions.

#ifndef _CGE_UTILFUNCTIONS_H_
#define _CGE_UTILFUNCTIONS_H_

#ifdef __OBJC__

#import "cgeSharedGLContext.h"
#import <GLKit/GLKit.h>

#endif

#ifdef __cplusplus
extern "C" {
#endif
    
#ifdef __OBJC__
    
    typedef UIImage* (*LoadImageCallback)(const char* name, void* arg);
    typedef void (*LoadImageOKCallback)(UIImage*, void* arg);
    
    void cgeSetLoadImageCallback(LoadImageCallback, LoadImageOKCallback, void* arg);
    
#endif
   
    GLuint cgeGlobalTextureLoadFunc(const char* source, GLint* w, GLint* h, void* arg);
    
    //Create single filter with config
    void* cgeCreateFilterByConfig(const char* config);
    
    //Create multiple filter with config. the return value must be kind of `CGEMutipleEffectFilter`
    void* cgeCreateMultipleFilterByConfig(const char* config, float intensity);
    
    typedef struct CGETextureInfo
    {
        GLint width, height;
        GLuint name;
    }CGETextureInfo;
    
    CGETextureInfo cgeLoadTextureByFile(const char* path);
    
#ifdef __OBJC__
    
    // 注意， 图片格式必须为 GL_RGBA + GL_UNSIGNED_BYTE
    typedef struct CGEFilterImageInfo
    {
        void* data; // char array.
        int width; //图片宽 (真实宽度， 需要将对齐计算在内)
        int height; //图片高 (真实高度， 需要将对齐计算在内)
    }CGEFilterImageInfo;
    
    // deprecated.
    void cgeFilterImage_MultipleEffects(CGEFilterImageInfo dataIn, CGEFilterImageInfo dataOut, const char* config, float intensity, CGESharedGLContext* processingContext);

    //image processing interface (recommand)
    //args:      uiimage － the input image
    //            config  - the filter rule string
    //         intensity  - range [0, 1]
    // processingContext  - additional context, if it's nil, the function will use a globalContext。
    //                      So if you want to use it in different threads, you need to create it in each thread.
    UIImage* cgeFilterUIImage_MultipleEffects(UIImage* uiimage, const char* config, float intensity, CGESharedGLContext* processingContext);
    
    //info 的 width 和 height 将被写入texture的真实宽高 (tips: 后期可能存在UIImage过大时， 纹理将被压缩， 所以只有从这里获得的参数才是准确值)
    CGETextureInfo cgeUIImage2Texture(UIImage* uiimage);
    
    
    //下面三个函数必须在绑定到正确状态之后才能正确调用.
    UIImage* cgeGrabUIImageWithCurrentFramebuffer(int x, int y, int w, int h); //从当前的fbo抓取UIImage
    UIImage* cgeGrabUIImageWithFramebuffer(int x, int y, int w, int h, GLuint fbo);
    UIImage* cgeGrabUIImageWithTexture(int x, int y, int w, int h, GLuint texture);
    
    //较快创建Texture的方法， 当imageBuffer为NULL 时将使用malloc创建合适大小的buffer。
    GLuint cgeCGImage2Texture(CGImageRef cgImage, void* imageBuffer);
    
    UIImage* cgeCreateUIImageWithBufferRGBA(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow);
    
    UIImage* cgeCreateUIImageWithBufferRGB(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow);
    
    UIImage* cgeCreateUIImageWithBufferBGRA(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow);
    
    UIImage* cgeCreateUIImageWithBufferGray(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow);
    
    //可以传入buffer作为缓存, 否则将创建一份新的buffer (malloc), 调用者需要负责 free
    char* cgeGenBufferWithCGImage(CGImageRef cgImage, char* buffer, bool isGray);
    
    CGAffineTransform cgeGetUIImageOrientationTransform(UIImage* image);
    UIImage* cgeForceUIImageUp(UIImage* image, int sizeLimit);

    ///////////////////////////////////
    
    CGColorSpaceRef cgeCGColorSpaceRGB(void);
    CGColorSpaceRef cgeCGColorSpaceGray(void);
    CGColorSpaceRef cgeCGColorSpaceCMYK(void);
    
    CGETextureInfo cgeLoadTextureByPath(NSString* path);
    CGETextureInfo cgeLoadTextureByURL(NSURL* url);
    
    UIImage* cgeLoadUIImageByPath(NSString* path);
    UIImage* cgeLoadUIImageByURL(NSURL* url);
    
#ifdef CGE_USE_WEBP

    CGImageRef cgeCGImageWithWebPData(CFDataRef webpData);
    CGImageRef cgeCGImageWithWebPDataExt(CFDataRef webpData, BOOL forDisplay, BOOL useThreads, BOOL bypassFiltering, BOOL noFancyUpsampling);
    
    UIImage* cgeUIImageWithWebPData(CFDataRef webPData);
    UIImage* cgeUIImageWithWebPURL(NSURL* url);
    UIImage* cgeUIImageWithWebPFile(NSString* filepath);

    //The result texture is always "GL_RGBA & GL_UNSIGNED_BYTE" 
    CGETextureInfo cgeGenTextureWithWebPData(CFDataRef webpData);
    
#endif
    /*
     
     cgeGetMachineDescriptionString 返回值对应表
     (from: http://stackoverflow.com/questions/448162/determine-device-iphone-ipod-touch-with-iphone-sdk )
     
     @"iPhone1,1" => @"iPhone 1G"
     @"iPhone1,2" => @"iPhone 3G"
     @"iPhone2,1" => @"iPhone 3GS"
     @"iPhone3,1" => @"iPhone 4"
     @"iPhone3,3" => @"Verizon iPhone 4"
     @"iPhone4,1" => @"iPhone 4S"
     @"iPhone5,1" => @"iPhone 5 (GSM)"
     @"iPhone5,2" => @"iPhone 5 (GSM+CDMA)"
     @"iPhone5,3" => @"iPhone 5c (GSM)"
     @"iPhone5,4" => @"iPhone 5c (GSM+CDMA)"
     @"iPhone6,1" => @"iPhone 5s (GSM)"
     @"iPhone6,2" => @"iPhone 5s (GSM+CDMA)"
     @"iPhone7,1" => @"iPhone 6 Plus"
     @"iPhone7,2" => @"iPhone 6"
     @"iPod1,1" => @"iPod Touch 1G"
     @"iPod2,1" => @"iPod Touch 2G"
     @"iPod3,1" => @"iPod Touch 3G"
     @"iPod4,1" => @"iPod Touch 4G"
     @"iPod5,1" => @"iPod Touch 5G"
     @"iPad1,1" => @"iPad"
     @"iPad2,1" => @"iPad 2 (WiFi)"
     @"iPad2,2" => @"iPad 2 (GSM)"
     @"iPad2,3" => @"iPad 2 (CDMA)"
     @"iPad2,4" => @"iPad 2 (WiFi)"
     @"iPad2,5" => @"iPad Mini (WiFi)"
     @"iPad2,6" => @"iPad Mini (GSM)"
     @"iPad2,7" => @"iPad Mini (GSM+CDMA)"
     @"iPad3,1" => @"iPad 3 (WiFi)"
     @"iPad3,2" => @"iPad 3 (GSM+CDMA)"
     @"iPad3,3" => @"iPad 3 (GSM)"
     @"iPad3,4" => @"iPad 4 (WiFi)"
     @"iPad3,5" => @"iPad 4 (GSM)"
     @"iPad3,6" => @"iPad 4 (GSM+CDMA)"
     @"iPad4,1" => @"iPad Air (WiFi)"
     @"iPad4,2" => @"iPad Air (Cellular)"
     @"iPad4,4" => @"iPad mini 2G (WiFi)"
     @"iPad4,5" => @"iPad mini 2G (Cellular)"
     
     @"iPad4,7" => @"iPad mini 3 (WiFi)"
     @"iPad4,8" => @"iPad mini 3 (Cellular)"
     @"iPad4,9" => @"iPad mini 3 (China Model)"
     
     @"iPad5,3" => @"iPad Air 2 (WiFi)"
     @"iPad5,4" => @"iPad Air 2 (Cellular)"
     
     @"i386" => @"Simulator"
     @"x86_64" => @"Simulator"
     */
    
    NSString* cgeGetMachineDescriptionString(void);
    
#endif
    
    typedef enum { CGEDevice_Simulator, CGEDevice_iPod, CGEDevice_iPhone, CGEDevice_iPad } CGEDeviceEnum;
    
    typedef struct
    {
        CGEDeviceEnum model;
        int majorVerion, minorVersion;
    } CGEDeviceDescription;
    
    CGEDeviceDescription cgeGetDeviceDescription(void);
    
#ifdef __cplusplus
}
#endif

#endif
