/*
 * cgeUtilFunctions.mm
 *
 *  Created on: 2015-7-10
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeUtilFunctions.h"
#import "cgeSharedGLContext.h"
#import "cgeFilters.h"

#import "cgeImageHandlerIOS.h"

#import <sys/utsname.h>

using namespace CGE;

struct CGELoadImageCallBackClass
{
    static UIImage* (*loadImage)(const char* name, void* arg);
    static void (*loadImageOK)(UIImage*, void* arg);
    static void* argument;
};

UIImage* (*CGELoadImageCallBackClass::loadImage)(const char* name, void* arg);
void (*CGELoadImageCallBackClass::loadImageOK)(UIImage*, void* arg);
void* CGELoadImageCallBackClass::argument;

extern "C"
{
    void cgeSetLoadImageCallback(LoadImageCallback loadCallback, LoadImageOKCallback loadOKCallback, void* arg)
    {
        CGELoadImageCallBackClass::loadImage = loadCallback;
        CGELoadImageCallBackClass::loadImageOK = loadOKCallback;
        CGELoadImageCallBackClass::argument = arg;
    }
    
    GLuint cgeGlobalTextureLoadFunc(const char* source, GLint* w, GLint* h, void* )
    {
        UIImage* image = nil;
        
        if(CGELoadImageCallBackClass::loadImage != nullptr)
        {
            image = CGELoadImageCallBackClass::loadImage(source, CGELoadImageCallBackClass::argument);
        }
        
        if(image == nil)
            return 0;
        
        CGETextureInfo texInfo = cgeUIImage2Texture(image);
        
        if(w != nullptr)
            *w = texInfo.width;
        if(h != nullptr)
            *h = texInfo.height;
        
        if(CGELoadImageCallBackClass::loadImageOK != nullptr)
        {
            CGELoadImageCallBackClass::loadImageOK(image, CGELoadImageCallBackClass::argument);
        }
        
        return  texInfo.name;
    }
  
    void cgeFilterImage_MultipleEffects(CGEFilterImageInfo dataIn, CGEFilterImageInfo dataOut, const char* config, float intensity, CGESharedGLContext* processingContext)
    {
        if(config == nullptr || *config == '\0')
            return ;
        
        id block = ^{
            if(processingContext != nil)
                [processingContext makeCurrent];
            else
                [CGESharedGLContext useGlobalGLContext];
            
            CGE_LOG_CODE
            (
             clock_t tm = clock();
             CGE_LOG_INFO("Filter Image.... The Configure is: \n%s\n", config);
             );
            
            CGEImageHandler handler;
            
            if(!handler.initWithRawBufferData(dataIn.data, dataIn.width, dataIn.height, CGE_FORMAT_RGBA_INT8, false))
            {
                CGE_LOG_ERROR("Init handler failed!!!!\n");
                return ;
            }
            
            
            CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
            filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
            filter->initWithEffectString(config);
            filter->setIntensity(intensity);
            
            handler.addImageFilter(filter);
            handler.processingFilters();
            
            CGE_LOG_INFO("Before getting output data...\n");
            handler.getOutputBufferData(dataOut.data, CGE_FORMAT_RGBA_INT8);
            CGE_LOG_INFO("After getting output data...\n");
            
            CGE_LOG_CODE
            (
             CGE_LOG_INFO("Filter Image OK, Total Time: %g\n", (clock() - tm) / (float)CLOCKS_PER_SEC);
             );
        };
        
        if(processingContext == nil)
        {
            [CGESharedGLContext globalSyncProcessingQueue:block];
        }
        else
        {
            [processingContext syncProcessingQueue:block];
        }

    }
    
    UIImage* cgeFilterUIImage_MultipleEffects(UIImage* uiimage, const char* config, float intensity, CGESharedGLContext* processingContext)
    {
        if(config == nullptr || *config == '\0' || uiimage == nil)
            return uiimage;
        
        __block UIImage* dstImg = nil;
        
        id block = ^{
            if(processingContext != nil)
                [processingContext makeCurrent];
            else
                [CGESharedGLContext useGlobalGLContext];
            
            CGE_LOG_CODE
            (
             clock_t tm = clock();
             CGE_LOG_INFO("Filter Image.... The Configure is: \n%s\n", config);
             );
            
            CGEImageHandlerIOS handler;
            
            if(!handler.initWithUIImage(uiimage, true))
            {
                CGE_LOG_ERROR("Init handler failed!!!!\n");
                return ;
            }
            
            CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
            filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
            filter->initWithEffectString(config);
            filter->setIntensity(intensity);
            
            handler.addImageFilter(filter);
            handler.processingFilters();
            
            dstImg = handler.getResultUIImage();
            
            CGE_LOG_CODE
            (
             CGE_LOG_INFO("Filter Image OK, Total Time: %g\n", (clock() - tm) / (float)CLOCKS_PER_SEC);
             );
        };
        
        if(processingContext == nil)
        {
            [CGESharedGLContext globalSyncProcessingQueue:block];
        }
        else
        {
            [processingContext syncProcessingQueue:block];
        }
        
        return dstImg;
    }
    
    CGETextureInfo cgeUIImage2Texture(UIImage* image)
    {
        CGETextureInfo info = {0};
        
        if(image == nil)
            return info;
        
        CGImageRef imageRef = [image CGImage];
        
        info.width = image.size.width;
        info.height = image.size.height;
        
        CGAffineTransform transform = cgeGetUIImageOrientationTransform(image);
        int bufferSize = info.width * info.height * 4;
        
        unsigned char* imageBuffer = (unsigned char*) malloc(bufferSize);
        
        if(imageBuffer == nullptr)
        {
            CGE_NSLog(@"❌Alloc buffer failed!!");
            CGEAssert(0);
            return info;
        }
        
        memset(imageBuffer, 0, bufferSize);
        
        CGContextRef context = CGBitmapContextCreate(imageBuffer, info.width, info.height, 8, 4 * info.width, cgeCGColorSpaceRGB(), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextConcatCTM(context, transform);
        CGContextDrawImage(context, CGRectMake(0, 0, info.width, info.height), imageRef);
        
        info.name = cgeGenTextureWithBuffer(imageBuffer, (int)info.width, (int)info.height, GL_RGBA, GL_UNSIGNED_BYTE);
        
        CGContextRelease(context);        
        free(imageBuffer);
        
        cgeCheckGLError("genTexture");
        
        return info;
    }
    
    UIImage* cgeGrabUIImageWithCurrentFramebuffer(int x, int y, int w, int h)
    {
        std::vector<char> vecData(w * h * 4);
        glReadPixels(x, y, w, h, GL_RGBA, GL_UNSIGNED_BYTE, vecData.data());
        return cgeCreateUIImageWithBufferRGBA(vecData.data(), w, h, 8, w * 4);
    }
    
    UIImage* cgeGrabUIImageWithFramebuffer(int x, int y, int w, int h, GLuint fbo)
    {
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        return cgeGrabUIImageWithCurrentFramebuffer(x, y, w, h);
    }
    
    UIImage* cgeGrabUIImageWithTexture(int x, int y, int w, int h, GLuint texture)
    {
        FrameBuffer fbo;
        fbo.bindTexture2D(texture);
        return cgeGrabUIImageWithCurrentFramebuffer(x, y, w, h);
    }
    
    GLuint cgeCGImage2Texture(CGImageRef imgRef, void* imageBuffer)
    {
        if(imgRef == nil)
            return 0;
        
        CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
        
        unsigned char* buffer = imageBuffer == nil ? (unsigned char*) malloc(imageSize.width * imageSize.height * 4) : (unsigned char*)imageBuffer;
        
        CGContextRef context = CGBitmapContextCreate(buffer, imageSize.width, imageSize.height, 8, 4 * imageSize.width, cgeCGColorSpaceRGB(), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        
        CGContextDrawImage(context, CGRectMake(0, 0, imageSize.width, imageSize.height), imgRef);
        
        GLuint texID = cgeGenTextureWithBuffer(buffer, (int)imageSize.width, (int)imageSize.height, GL_RGBA, GL_UNSIGNED_BYTE);
        
        CGContextRelease(context);
        
        if(imageBuffer == nil)
            free(buffer);
        
        return texID;
    }
    
    CGAffineTransform cgeGetUIImageOrientationTransform(UIImage* image)
    {
        // fix orientation:
        
        CGAffineTransform transform = CGAffineTransformIdentity;
        
        UIImageOrientation orientation = [image imageOrientation];
        
        CGImageRef imageRef = [image CGImage];
        int width = (int)CGImageGetWidth(imageRef);
        int height = (int)CGImageGetHeight(imageRef);
        
        int newWidth = image.size.width;
        int newHeight = image.size.height;
        
        switch (orientation)
        {
            case UIImageOrientationDown:
            case UIImageOrientationDownMirrored:
                transform = CGAffineTransformTranslate(transform, newWidth, newHeight);
                transform = CGAffineTransformRotate(transform, M_PI);
                break;
                
            case UIImageOrientationLeft:
            case UIImageOrientationLeftMirrored:
                transform = CGAffineTransformTranslate(transform, newWidth, 0);
                transform = CGAffineTransformRotate(transform, M_PI_2);
                break;
                
            case UIImageOrientationRight:
            case UIImageOrientationRightMirrored:
                transform = CGAffineTransformTranslate(transform, 0, newHeight);
                transform = CGAffineTransformRotate(transform, -M_PI_2);
                break;
            default:
                break;
        }
        
        switch (orientation)
        {
            case UIImageOrientationUpMirrored:
            case UIImageOrientationDownMirrored:
                transform = CGAffineTransformTranslate(transform, width, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
                break;
            case UIImageOrientationLeftMirrored:
            case UIImageOrientationRightMirrored:
                transform = CGAffineTransformTranslate(transform, 0, height);
                transform = CGAffineTransformScale(transform, 1, -1);
                break;
                
            default:
                break;
        }
        
        return transform;
    }
    
    UIImage* cgeForceUIImageUp(UIImage* image, int sizeLimit)
    {
        if(image.imageOrientation == UIImageOrientationUp && (sizeLimit <= 0 || (image.size.width < sizeLimit && image.size.height < sizeLimit)))
        {
            return image;
        }
        
        CGAffineTransform transform = cgeGetUIImageOrientationTransform(image);
        
        int newWidth = image.size.width;
        int newHeight = image.size.height;
        
        if(sizeLimit > 0)
        {
            float scaling = std::min(sizeLimit / (float)newWidth, sizeLimit / (float)newHeight);
            newWidth *= scaling;
            newHeight *= scaling;
            
            //fix transform calc for size limit.
            transform.tx *= scaling;
            transform.ty *= scaling;
        }
        
        CGImageRef imageRef = image.CGImage;
        
        CGContextRef ctx = CGBitmapContextCreate(NULL, newWidth, newHeight,
                                                 8, 0,
                                                 cgeCGColorSpaceRGB(),
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        CGContextConcatCTM(ctx, transform);
        
        switch (image.imageOrientation) {
            case UIImageOrientationLeft:
            case UIImageOrientationLeftMirrored:
            case UIImageOrientationRight:
            case UIImageOrientationRightMirrored:
                // Grr...
                CGContextDrawImage(ctx, CGRectMake(0, 0, newHeight, newWidth), imageRef);
                break;
                
            default:
                CGContextDrawImage(ctx, CGRectMake(0, 0, newWidth, newHeight), imageRef);
                break;
        }
        
        // And now we just create a new UIImage from the drawing context
        CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
        UIImage *img = [UIImage imageWithCGImage:cgimg];
        CGContextRelease(ctx);
        CGImageRelease(cgimg);
        return img;
    }
    
    void* cgeCreateFilterByConfig(const char* config)
    {
        CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
        filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
        if(!filter->initWithEffectString(config))
        {
            delete filter;
            filter = nullptr;
            return nullptr;
        }
        
        if(!filter->isWrapper())
        {
            return filter;
        }
        
        auto&& filters = filter->getFilters(true);
        delete filter;
        
        if(filters.empty())
            return nullptr;
        return filters[0];
    }
    
    void* cgeCreateMultipleFilterByConfig(const char* config, float intensity)
    {
        CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
        filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
        if(!filter->initWithEffectString(config))
        {
            delete filter;
            return nullptr;
        }
        
        filter->setIntensity(intensity);
        return filter;
    }
    
    static inline UIImage* cgeCreateUIImageWithBuffer(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow, int flag, CGColorSpaceRef colorSpaceRef)
    {
        CGEAssert(colorSpaceRef != nil);
        CGContextRef contextOut = CGBitmapContextCreate(buffer, width, height, bitsPerComponent, bytesPerRow, colorSpaceRef, flag);
        
        CGImageRef frame = CGBitmapContextCreateImage(contextOut);
        UIImage* newImage = [UIImage imageWithCGImage:frame];
        
        CGImageRelease(frame);
        CGContextRelease(contextOut);
        return newImage;
    }
    
    UIImage* cgeCreateUIImageWithBufferRGBA(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow)
    {
        return cgeCreateUIImageWithBuffer(buffer, width, height, bitsPerComponent, bytesPerRow, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, cgeCGColorSpaceRGB());
    }
    
    UIImage* cgeCreateUIImageWithBufferRGB(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow)
    {
        return cgeCreateUIImageWithBuffer(buffer, width, height, bitsPerComponent, bytesPerRow, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big, cgeCGColorSpaceRGB());
    }
    
    UIImage* cgeCreateUIImageWithBufferBGRA(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow)
    {        
        return cgeCreateUIImageWithBuffer(buffer, width, height, bitsPerComponent, bytesPerRow, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, cgeCGColorSpaceRGB());
    }
    
    UIImage* cgeCreateUIImageWithBufferGray(void* buffer, size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow)
    {
        return cgeCreateUIImageWithBuffer(buffer, width, height, bitsPerComponent, bytesPerRow, kCGImageAlphaNone, cgeCGColorSpaceGray());
    }
    
    char* cgeGenBufferWithCGImage(CGImageRef imgRef, char* buffer, bool isGray)
    {
        if(imgRef == nil)
            return nullptr;
        
        size_t width = CGImageGetWidth(imgRef);
        size_t height = CGImageGetHeight(imgRef);
        size_t stride;
        
        CGContextRef context = nil;
        
        char* imageBuffer = buffer;
        
        if(isGray)
        {
            stride = width;
            
            if(imageBuffer == nullptr)
                imageBuffer = (char*) malloc(stride * height);
            context = CGBitmapContextCreate(imageBuffer, width, height, 8, stride, cgeCGColorSpaceGray(), kCGImageAlphaNone);
        }
        else
        {
            stride = width * 4;
            
            if(imageBuffer == nullptr)
                imageBuffer = (char*) malloc(stride * height);
            context = CGBitmapContextCreate(imageBuffer, width, height, 8, stride, cgeCGColorSpaceRGB(), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        }
        
        if(context != nil)
        {
            CGContextDrawImage(context, CGRectMake(0, 0, width, height), imgRef);
            CGContextRelease(context);
        }
        else
        {
            if(buffer == nullptr)
                free(imageBuffer);
            imageBuffer = nullptr;
        }
        
        return imageBuffer;
    }
    
    CGColorSpaceRef cgeCGColorSpaceRGB()
    {
        static CGColorSpaceRef colorSpace;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            colorSpace = CGColorSpaceCreateDeviceRGB();
        });
        return colorSpace;
    }
    
    CGColorSpaceRef cgeCGColorSpaceGray()
    {
        static CGColorSpaceRef colorSpace;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            colorSpace = CGColorSpaceCreateDeviceGray();
        });
        return colorSpace;
    }
    
    CGColorSpaceRef cgeCGColorSpaceCMYK()
    {
        static CGColorSpaceRef colorSpace;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            colorSpace = CGColorSpaceCreateDeviceCMYK();
        });
        return colorSpace;
    }
    
    CGETextureInfo cgeLoadTextureByFile(const char* pathName)
    {
        return cgeLoadTextureByPath(@(pathName));
    }
    
    CGETextureInfo cgeLoadTextureByPath(NSString* path)
    {
#ifdef CGE_USE_WEBP
        
        if([[path lowercaseString] hasSuffix:@"webp"])
        {
            CGE_LOG_INFO("decoding webp image...\n");
            CGE_LOG_CODE
            (
             double tm = CFAbsoluteTimeGetCurrent();
            );
            
            NSData* data = [NSData dataWithContentsOfFile:path];
            const CGETextureInfo& info = cgeGenTextureWithWebPData((__bridge CFDataRef)data);
            
            CGE_LOG_CODE
            (
             CGE_LOG_INFO("webp image generate texture time: %f\n", (CFAbsoluteTimeGetCurrent() - tm));
            )
            
            return info;
        }
        
#endif
        
        CGETextureInfo info = {0};
        
#if 1 //不使用GLKTextureLoader - 2017/10/25
        UIImage* tmpImg = [UIImage imageWithContentsOfFile:path];
        if(tmpImg)
        {
            info = cgeUIImage2Texture(tmpImg);
        }
        return info;
        
#else
        
        NSError* err = nil;
        
#if 1 //修正ios10+的bug: https://forums.developer.apple.com/thread/61190
        
        static int s_sysVer = -1;
        
        if(s_sysVer <= 0)
        {
            NSString* sysVer = [[UIDevice currentDevice] systemVersion];
            s_sysVer = [sysVer intValue];
        }
        
        if(s_sysVer >= 10)
        {
            UIImage* tmpImg = [UIImage imageWithContentsOfFile:path];
            if(tmpImg)
            {
                info = cgeUIImage2Texture(tmpImg);
            }
            return info;
        }
        
#endif
        
        GLKTextureInfo* glkTexInfo = [GLKTextureLoader textureWithContentsOfFile:path options:CGE_GLK_TEXTURE_OPTION error:&err];
        
        if(glkTexInfo == nil || glkTexInfo.name == 0 || err)
        {
#if defined(_CGE_GENERAL_ERROR_TEST_) && _CGE_GENERAL_ERROR_TEST_
            CGE_NSLog(@"GLKTextureLoader load image failed, crash! The image format is not supported, please fix!");
            
            [CGEProcessingContext mainASyncProcessingQueue:^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"检测到不支持的图片, 请修复: %@", path] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            }];
            
#else
            CGE_NSLog(@"GLKTextureLoader load image failed, try to reload with CGE because of release mode!");
            UIImage* tmpImg = [UIImage imageWithContentsOfFile:path];
            if(tmpImg)
            {
                info = cgeUIImage2Texture(tmpImg);
            }
#endif
        }
        else
        {
            info.name = glkTexInfo.name;
            info.width = glkTexInfo.width;
            info.height = glkTexInfo.height;
//            info.channelFormat = (glkTexInfo.alphaState == GLKTextureInfoAlphaStateNone) ? GL_RGB : GL_RGBA;
//            info.dataFormat = GL_UNSIGNED_BYTE;
        }
        
        return info;
#endif
    }
    
    CGETextureInfo cgeLoadTextureByURL(NSURL* url)
    {
        return cgeLoadTextureByPath(url.path);
    }
    
    UIImage* cgeLoadUIImageByPath(NSString* path)
    {
#ifdef CGE_USE_WEBP
        
        if([[path lowercaseString] hasSuffix:@"webp"])
        {
            CGE_LOG_INFO("decoding webp image...\n");
            
            CGE_LOG_CODE
            (
             double tm = CFAbsoluteTimeGetCurrent();
             );
            
            NSData* data = [NSData dataWithContentsOfFile:path];
            
            CGImageRef cgImgRef = cgeCGImageWithWebPData((__bridge CFDataRef)data);
            
            CGE_LOG_CODE
            (
             CGE_LOG_INFO("webp image generate texture time: %f\n", (CFAbsoluteTimeGetCurrent() - tm));
             )
            
            return [UIImage imageWithCGImage:cgImgRef];
        }
        
#endif
        return [UIImage imageWithContentsOfFile:path];
    }
    
    UIImage* cgeLoadUIImageByURL(NSURL* url)
    {
        return [UIImage imageWithContentsOfFile:url.path];
    }
    
    NSString* cgeGetMachineDescriptionString()
    {
        struct utsname sysInfo;
        uname(&sysInfo);
        return [NSString stringWithUTF8String:sysInfo.machine];
    }
    
    CGEDeviceDescription cgeGetDeviceDescription()
    {
        static CGEDeviceDescription deviceDescription = {
            CGEDevice_Simulator, 0, 0
        };
        static dispatch_once_t onceToken;
        
        dispatch_once(&onceToken, ^{
            NSString* dscrpt = cgeGetMachineDescriptionString();
            CGE_NSLog(@"device name: %@", dscrpt);
            
            NSString* deviceDescriptionString = [dscrpt lowercaseString];
            
            
            deviceDescription.model = [deviceDescriptionString rangeOfString:@"ipod"].location == NSNotFound ? deviceDescription.model : CGEDevice_iPod;
            deviceDescription.model = [deviceDescriptionString rangeOfString:@"iphone"].location == NSNotFound ? deviceDescription.model : CGEDevice_iPhone;
            deviceDescription.model = [deviceDescriptionString rangeOfString:@"ipad"].location == NSNotFound ? deviceDescription.model : CGEDevice_iPad;
            
            if(deviceDescription.model != CGEDevice_Simulator)
            {
                sscanf([deviceDescriptionString cStringUsingEncoding:NSUTF8StringEncoding], "%*[^0-9]%d%*c%d", &deviceDescription.majorVerion, &deviceDescription.minorVersion);
            }
        });
        
        return deviceDescription;
    }
}

#ifdef CGE_USE_WEBP

#import "webp/decode.h"
#import "webp/demux.h"

extern "C"
{
    static void cgeCGDataProviderReleaseDataCallback(void *info, const void *data, size_t size)
    {
        free(info);
    }
    
    static inline size_t cgeImageByteAlign(size_t size, size_t alignment) {
        return ((size + (alignment - 1)) / alignment) * alignment;
    }
    
    CGImageRef cgeCGImageWithWebPData(CFDataRef webpData)
    {
        return cgeCGImageWithWebPDataExt(webpData, NO, NO, NO, NO);
    }
    
    //ref: https://github.com/ibireme/YYImage
    CGImageRef cgeCGImageWithWebPDataExt(CFDataRef webpData, BOOL decodeForDisplay,
                                         BOOL useThreads,
                                         BOOL bypassFiltering,
                                         BOOL noFancyUpsampling)
    {
        WebPData data = {0};
        WebPDemuxer *demuxer = NULL;
        
        int frameCount = 0, canvasWidth = 0, canvasHeight = 0;
        WebPIterator iter = {0};
        BOOL iterInited = NO;
        const uint8_t *payload = NULL;
        size_t payloadSize = 0;
        WebPDecoderConfig config = {0};
        
        BOOL hasAlpha = NO;
        size_t bitsPerComponent = 0, bitsPerPixel = 0, bytesPerRow = 0, destLength = 0;
        CGBitmapInfo bitmapInfo = 0;
        WEBP_CSP_MODE colorspace = MODE_RGB;
        void *destBytes = NULL;
        CGDataProviderRef provider = NULL;
        CGImageRef imageRef = NULL;
        {
            if (!webpData || CFDataGetLength(webpData) == 0) return NULL;
            data.bytes = CFDataGetBytePtr(webpData);
            data.size = CFDataGetLength(webpData);
            demuxer = WebPDemux(&data);
            if (!demuxer) goto fail;
            
            frameCount = WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT);
            if (frameCount == 0) {
                goto fail;
                
            } else if (frameCount == 1) { // single-frame
                payload = data.bytes;
                payloadSize = data.size;
                if (!WebPInitDecoderConfig(&config)) goto fail;
                if (WebPGetFeatures(payload , payloadSize, &config.input) != VP8_STATUS_OK) goto fail;
                canvasWidth = config.input.width;
                canvasHeight = config.input.height;
                
            } else { // multi-frame
                canvasWidth = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_WIDTH);
                canvasHeight = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_HEIGHT);
                if (canvasWidth < 1 || canvasHeight < 1) goto fail;
                
                if (!WebPDemuxGetFrame(demuxer, 1, &iter)) goto fail;
                iterInited = YES;
                
                if (iter.width > canvasWidth || iter.height > canvasHeight) goto fail;
                payload = iter.fragment.bytes;
                payloadSize = iter.fragment.size;
                
                if (!WebPInitDecoderConfig(&config)) goto fail;
                if (WebPGetFeatures(payload , payloadSize, &config.input) != VP8_STATUS_OK) goto fail;
            }
            if (payload == NULL || payloadSize == 0) goto fail;
            
            hasAlpha = config.input.has_alpha;
            bitsPerComponent = 8;
            bitsPerPixel = 32;
            bytesPerRow = cgeImageByteAlign(bitsPerPixel / 8 * canvasWidth, 32);
            destLength = bytesPerRow * canvasHeight;
            if (decodeForDisplay) {
                bitmapInfo = kCGBitmapByteOrder32Host;
                bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
                colorspace = MODE_bgrA; // small endian
            } else {
                bitmapInfo = kCGBitmapByteOrder32Big;
                bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNoneSkipLast;
                colorspace = MODE_rgbA;
            }
            destBytes = calloc(1, destLength);
            if (!destBytes) goto fail;
            
            config.options.use_threads = useThreads; //speed up 23%
            config.options.bypass_filtering = bypassFiltering; //speed up 11%, cause some banding
            config.options.no_fancy_upsampling = noFancyUpsampling; //speed down 16%, lose some details
            config.output.colorspace = colorspace;
            config.output.is_external_memory = 1;
            config.output.u.RGBA.rgba = (unsigned char*)destBytes;
            config.output.u.RGBA.stride = (int)bytesPerRow;
            config.output.u.RGBA.size = destLength;
            
            VP8StatusCode result = WebPDecode(payload, payloadSize, &config);
            if ((result != VP8_STATUS_OK) && (result != VP8_STATUS_NOT_ENOUGH_DATA)) goto fail;
            
//            if (iter.x_offset != 0 || iter.y_offset != 0) {
//                void *tmp = calloc(1, destLength);
//                if (tmp) {
//                    vImage_Buffer src = {destBytes, static_cast<vImagePixelCount>(canvasHeight), static_cast<vImagePixelCount>(canvasWidth), bytesPerRow};
//                    vImage_Buffer dest = {tmp, static_cast<vImagePixelCount>(canvasHeight), static_cast<vImagePixelCount>(canvasWidth), bytesPerRow};
//                    vImage_CGAffineTransform transform = {1, 0, 0, 1, static_cast<double>(iter.x_offset), static_cast<double>(-iter.y_offset)};
//                    uint8_t backColor[4] = {0};
//                    vImageAffineWarpCG_ARGB8888(&src, &dest, NULL, &transform, backColor, kvImageBackgroundColorFill);
//                    memcpy(destBytes, tmp, destLength);
//                    free(tmp);
//                }
//            }
            
            provider = CGDataProviderCreateWithData(destBytes, destBytes, destLength, cgeCGDataProviderReleaseDataCallback);
            if (!provider) goto fail;
            destBytes = NULL; // hold by provider
            
            imageRef = CGImageCreate(canvasWidth, canvasHeight, bitsPerComponent, bitsPerPixel, bytesPerRow, cgeCGColorSpaceRGB(), bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
            
            CFRelease(provider);
            if (iterInited) WebPDemuxReleaseIterator(&iter);
            WebPDemuxDelete(demuxer);
        }
        
        return imageRef;
        
    fail:
        if (destBytes) free(destBytes);
        if (provider) CFRelease(provider);
        if (iterInited) WebPDemuxReleaseIterator(&iter);
        if (demuxer) WebPDemuxDelete(demuxer);
        return NULL;
    }
    
    UIImage* cgeUIImageWithWebPData(CFDataRef webPData)
    {
        CGImageRef cgImgRef = cgeCGImageWithWebPData(webPData);
        return [UIImage imageWithCGImage:cgImgRef];
    }
    
    UIImage* cgeUIImageWithWebPURL(NSURL* url)
    {
        NSData* data = [NSData dataWithContentsOfURL:url];
        return cgeUIImageWithWebPData((__bridge CFDataRef)data);
    }
    
    UIImage* cgeUIImageWithWebPFile(NSString* filepath)
    {
        NSData* data = [NSData dataWithContentsOfFile:filepath];
        return cgeUIImageWithWebPData((__bridge CFDataRef)data);
    }

    CGETextureInfo cgeGenTextureWithWebPData(CFDataRef webpData)
    {
        WebPData data = {0};
        WebPDemuxer *demuxer = NULL;
        
        int frameCount = 0, canvasWidth = 0, canvasHeight = 0;
        WebPIterator iter = {0};
        BOOL iterInited = NO;
        const uint8_t *payload = NULL;
        size_t payloadSize = 0;
        WebPDecoderConfig config = {0};
        
        size_t bytesPerRow = 0, destLength = 0;
        WEBP_CSP_MODE colorspace = MODE_RGB;
        void *destBytes = NULL;
        CGETextureInfo texInfo = {0};
        
        do
        {
            if (!webpData || CFDataGetLength(webpData) == 0) return texInfo;
            data.bytes = CFDataGetBytePtr(webpData);
            data.size = CFDataGetLength(webpData);
            demuxer = WebPDemux(&data);
            if (!demuxer) break;
            
            frameCount = WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT);
            if (frameCount != 1) {
                break;
                
            } else { // single-frame
                payload = data.bytes;
                payloadSize = data.size;
                if (!WebPInitDecoderConfig(&config) || WebPGetFeatures(payload , payloadSize, &config.input) != VP8_STATUS_OK) break;
                canvasWidth = config.input.width;
                canvasHeight = config.input.height;
            }
            
            if (payload == NULL || payloadSize == 0) break;
            
#if 1
            bytesPerRow = cgeImageByteAlign(4 * canvasWidth, 32);
#else
            bytesPerRow = channels * canvasWidth;
#endif
            destLength = bytesPerRow * canvasHeight;

            colorspace = MODE_rgbA;
            destBytes = calloc(1, destLength);
            if (!destBytes) break;
            
            config.options.use_threads = NO; //speed up 23%
            config.options.bypass_filtering = NO; //speed up 11%, cause some banding
            config.options.no_fancy_upsampling = NO; //speed down 16%, lose some details
            config.output.colorspace = colorspace;
            config.output.is_external_memory = 1;
            config.output.u.RGBA.rgba = (unsigned char*)destBytes;
            config.output.u.RGBA.stride = (int)bytesPerRow;
            config.output.u.RGBA.size = destLength;
            
            VP8StatusCode result = WebPDecode(payload, payloadSize, &config);
            if ((result != VP8_STATUS_OK) && (result != VP8_STATUS_NOT_ENOUGH_DATA)) break;
            
            texInfo.width = (int)bytesPerRow / 4;
            texInfo.height = canvasHeight;
            texInfo.name = cgeGenTextureWithBuffer(destBytes, texInfo.width, canvasHeight, GL_RGBA, GL_UNSIGNED_BYTE, 4);
            
            free(destBytes);
            if (iterInited) WebPDemuxReleaseIterator(&iter);
            WebPDemuxDelete(demuxer);
            return texInfo;
            
        }while(0);
        
        if (destBytes) free(destBytes);
        if (iterInited) WebPDemuxReleaseIterator(&iter);
        if (demuxer) WebPDemuxDelete(demuxer);
        return texInfo;
    }
    
}

#endif







