/*
 * cgeImageHandlerIOS.mm
 *
 *  Created on: 2015-8-23
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#include "cgeImageHandlerIOS.h"
#import "cgeUtilFunctions.h"

namespace CGE
{
    CGEImageHandlerIOS::CGEImageHandlerIOS() : m_imageBuffer(nullptr), m_imageScale(1.0f)
    {
    }
    
    CGEImageHandlerIOS::~CGEImageHandlerIOS()
    {
        free(m_imageBuffer);
        CGE_LOG_INFO("CGEImageHandlerIOS::~CGEImageHandlerIOS called...\n");
    }
    
    bool CGEImageHandlerIOS::initWithUIImage(UIImage *image, bool useImageBuffer, bool enableRevision)
    {
        if(image == nil)
            return false;
        
        // fix orientation:
        
        CGAffineTransform transform = cgeGetUIImageOrientationTransform(image);

        //Fix For Image Size Setting.
        m_imageScale = image.scale;

        CGImageRef imageRef = [image CGImage];
        int width = (int)CGImageGetWidth(imageRef);
        int height = (int)CGImageGetHeight(imageRef);
        GLint newWidth = image.size.width * m_imageScale;
        GLint newHeight = image.size.height * m_imageScale;

        if(m_imageBuffer == nullptr || m_dstImageSize.width != newWidth || m_dstImageSize.height != newHeight)
        {
            free(m_imageBuffer);
            m_imageBufferLen = newWidth * newHeight * 4;
            m_imageBuffer = (unsigned char*) malloc(m_imageBufferLen);
            m_dstImageSize.set(newWidth, newHeight);
        }
        
        CGContextRef context = CGBitmapContextCreate(m_imageBuffer, newWidth, newHeight, 8, 4 * newWidth, cgeCGColorSpaceRGB(), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        
        CGContextConcatCTM(context, transform);
        
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        
        bool flag = initWithRawBufferData(m_imageBuffer, newWidth, newHeight, CGE_FORMAT_RGBA_INT8, enableRevision);
        
        CGContextRelease(context);
        
        if(!useImageBuffer)
        {
            free(m_imageBuffer);
            m_imageBuffer = nullptr;
        }
        
        return flag;
    }
    
    UIImage* CGEImageHandlerIOS::getResultUIImage()
    {
        bool keepBuffer;
        if(m_imageBuffer == nullptr)
        {
            m_imageBufferLen = m_dstImageSize.height * m_dstImageSize.width * 4;
            m_imageBuffer = (unsigned char*) malloc(m_imageBufferLen);
            keepBuffer = false;
        }
        else
        {
            keepBuffer = true;
        }
        
        getOutputBufferData(m_imageBuffer, CGE_FORMAT_RGBA_INT8);
        
        CGContextRef contextOut = CGBitmapContextCreate(m_imageBuffer, m_dstImageSize.width, m_dstImageSize.height, 8, 4 * m_dstImageSize.width, cgeCGColorSpaceRGB(), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        
        CGImageRef frame = CGBitmapContextCreateImage(contextOut);
        UIImage* newImage = [UIImage imageWithCGImage:frame scale:m_imageScale orientation:UIImageOrientationUp];
        
        CGImageRelease(frame);
        CGContextRelease(contextOut);
        
        if(!keepBuffer)
        {
            free(m_imageBuffer);
            m_imageBuffer = nullptr;
        }
        
        return newImage;
    }
    
    void CGEImageHandlerIOS::enableImageBuffer(bool useBuffer)
    {
        if(!useBuffer)
        {
            free(m_imageBuffer);
            m_imageBuffer = nullptr;
            m_imageBufferLen = 0;
            return;
        }
        
        if(m_imageBuffer == nullptr || m_imageBufferLen != m_dstImageSize.width * m_dstImageSize.height * 4)
        {
            m_imageBufferLen = m_dstImageSize.width * m_dstImageSize.height * 4;
            m_imageBuffer = (unsigned char*)realloc(m_imageBuffer, m_imageBufferLen);
        }
    }
    
    void CGEImageHandlerIOS::swapBufferFBO()
    {
        glBindFramebuffer(GL_FRAMEBUFFER, m_dstFrameBuffer);
        std::swap(m_bufferTextures[0], m_bufferTextures[1]);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_bufferTextures[0], 0);        
        
        CGE_LOG_CODE
        (
         if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
         {
             CGE_LOG_ERROR("Image Handler swapBufferFBO failed!\n");
         }
        )
    }
    
    void CGEImageHandlerIOS::processingFilters()
    {
        if(m_vecFilters.empty() || m_bufferTextures[0] == 0)
        {
            glFlush();
            return;
        }
        
        glDisable(GL_BLEND);
        CGEAssert(m_vertexArrayBuffer != 0);
        
        for(auto* filter : m_vecFilters)
        {
            swapBufferFBO();
            glBindBuffer(GL_ARRAY_BUFFER, m_vertexArrayBuffer);
            filter->render2Texture(this, m_bufferTextures[1], m_vertexArrayBuffer);
            glFlush();
        }
        
        glFinish();
    }
}
