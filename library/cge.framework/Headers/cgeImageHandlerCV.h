/*
 * cgeImageHandlerCV.h
 *
 *  Created on: 2015-7-11
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#ifndef _CGEImageHandlerCV_h
#define _CGEImageHandlerCV_h

#import "cgeImageHandler.h"
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

namespace CGE
{
    class CGEImageHandlerCV : public CGE::CGEImageHandler
    {
    public:
        
        typedef struct ImageInfo
        {
            size_t width;
            size_t height;
            size_t channel;
            size_t bitsPerComponent;
            size_t bytesPerRow;
        } ImageInfo;
        
        typedef struct CVPixelObject
        {
            CVPixelBufferRef pixBufferRef;
            CVOpenGLESTextureRef renderTextureRef;
            CVOpenGLESTextureCacheRef textureCacheRef;
            
            void cleanUp()
            {
                CVPixelBufferRelease(pixBufferRef);
                pixBufferRef = NULL;
                
                if (renderTextureRef != NULL)
                {
                    CFRelease(renderTextureRef);
                    renderTextureRef = NULL;
                }
                
                if (textureCacheRef != NULL)
                {
                    CVOpenGLESTextureCacheFlush(textureCacheRef, 0);
                    CFRelease(textureCacheRef);
                    textureCacheRef = NULL;
                }
            }
        } CVPixelObject;

        
        CGEImageHandlerCV() : m_CVPixelObject(), m_rawData(), m_cvEnabled(true), m_dataLen(0){}
        ~CGEImageHandlerCV();
        bool initWithRawDataCV(void *data, ImageInfo info, CGEBufferFormat format, bool enableReversion, bool bForceCV = false);
        CVPixelBufferRef getRenderTarget() { return m_CVPixelObject[0].pixBufferRef; }
        bool getOutputBufferData(void* data, CGEBufferFormat fmt);
        size_t getOutputBufferLen(size_t channel = 4);
        size_t getOutputBufferBytesPerRow(size_t channel = 4);
        void swapBufferFBO();
        void disableReversion();
        
    protected:
        bool initImageFBOCV(ImageInfo info);
        void clearImageFBOCV();
        
        
    protected:
        CVPixelObject m_CVPixelObject[2];
        char* m_rawData;
        int m_dataLen;
        bool m_cvEnabled;
    };
    

}



#endif
