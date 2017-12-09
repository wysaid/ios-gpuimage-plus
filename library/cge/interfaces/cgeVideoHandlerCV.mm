/*
 * cgeVideoHandlerCV.mm
 *
 *  Created on: 2015-9-8
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeVideoHandlerCV.h"
#import "cgeTextureUtils.h"

namespace CGE
{
    CGEVideoHandlerCV::CGEVideoHandlerCV() : m_videoTextureCacheRef(nil), m_lumaTextureRef(nil), m_chromaTextureRef(nil), m_yuvDrawer(nullptr), m_reverseTargetSize(false)
    {
        
    }
    
    CGEVideoHandlerCV::~CGEVideoHandlerCV()
    {
        delete m_yuvDrawer;
        
        if(m_videoTextureCacheRef != nil)
        {
            CFRelease(m_videoTextureCacheRef);
            m_videoTextureCacheRef = nil;
        }
        
        cleanupYUVTextures();
        CGE_LOG_INFO("CGEVideoHandlerCV release...\n");
    }
    
    bool CGEVideoHandlerCV::initHandler()
    {
        m_bRevertEnabled = false;
        
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, [EAGLContext currentContext], nil, &m_videoTextureCacheRef);
        
        if(err != kCVReturnSuccess)
            return false;

        if(m_vertexArrayBuffer == 0)
            m_vertexArrayBuffer = cgeGenCommonQuadArrayBuffer();

        //init drawer
        m_yuvDrawer = TextureDrawerYUV::create();
        CGEAssert(m_yuvDrawer != nullptr);
        return true;
    }
    
    void CGEVideoHandlerCV::cleanupYUVTextures()
    {
        if(m_lumaTextureRef != nil)
        {
            CFRelease(m_lumaTextureRef);
            m_lumaTextureRef = nil;
        }
        
        if(m_chromaTextureRef != nil)
        {
            CFRelease(m_chromaTextureRef);
            m_chromaTextureRef = nil;
        }
        
        if(m_videoTextureCacheRef != nil)
            CVOpenGLESTextureCacheFlush(m_videoTextureCacheRef, 0);
    }
    
    bool CGEVideoHandlerCV::updateFrameWithCVImageBuffer(CVImageBufferRef bufferRef)
    {
        if(bufferRef == nil)
            return false;
        
        GLint srcWidth = (GLint)CVPixelBufferGetWidth(bufferRef);
        GLint srcHeight = (GLint)CVPixelBufferGetHeight(bufferRef);
        
        auto ret = (srcWidth > 0) && (srcHeight > 0);
        
        if(!ret)
            return false;

        GLint transWidth, transHeight;

        if(m_reverseTargetSize)
        {
            transWidth = srcHeight;
            transHeight = srcWidth;
        }
        else
        {
            transWidth = srcWidth;
            transHeight = srcHeight;
        }
        
        if(transWidth != m_dstImageSize.width || transHeight != m_dstImageSize.height)
        {
            m_dstImageSize.set(transWidth, transHeight);
            if(!initImageFBO(nullptr, transWidth, transHeight, GL_RGBA, GL_UNSIGNED_BYTE, 4))
            {
                CGE_LOG_ERROR("CGEVideoHandlerCV - initImageFBO failed!");
                return  false;
            }
        }
        
        if (CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         m_videoTextureCacheRef,
                                                         bufferRef,
                                                         nil,
                                                         GL_TEXTURE_2D,
                                                         GL_RED_EXT,
                                                         srcWidth,
                                                         srcHeight,
                                                         GL_RED_EXT,
                                                         GL_UNSIGNED_BYTE,
                                                         0,
                                                         &m_lumaTextureRef) ||
            
            CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         m_videoTextureCacheRef,
                                                         bufferRef,
                                                         nil,
                                                         GL_TEXTURE_2D,
                                                         GL_RG_EXT,
                                                         srcWidth >> 1,
                                                         srcHeight >> 1,
                                                         GL_RG_EXT,
                                                         GL_UNSIGNED_BYTE,
                                                         1,
                                                         &m_chromaTextureRef))
        {
            CGE_LOG_ERROR("Error at CVOpenGLESTextureCacheCreateTextureFromImage");
            return false;
        }
        
        glBindFramebuffer(GL_FRAMEBUFFER, m_dstFrameBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_bufferTextures[0], 0);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
            CGE_LOG_ERROR("Image Handler initImageFBO failed!\n");
            return false;
        }
        
        glViewport(0, 0, (GLsizei)m_dstImageSize.width, (GLsizei)m_dstImageSize.height);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(CVOpenGLESTextureGetTarget(m_lumaTextureRef), CVOpenGLESTextureGetName(m_lumaTextureRef));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(CVOpenGLESTextureGetTarget(m_chromaTextureRef), CVOpenGLESTextureGetName(m_chromaTextureRef));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        m_yuvDrawer->bindVertexBuffer();
        
        m_yuvDrawer->drawTextures();
        
        cleanupYUVTextures();
        
        return true;

    }
    
    void CGEVideoHandlerCV::processingFilters()
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
        
//        cgeCheckGLError("CGEVideoHandlerCV::processingFilters");
    }
    
    void CGEVideoHandlerCV::swapBufferFBO()
    {
        useImageFBO();
        std::swap(m_bufferTextures[0], m_bufferTextures[1]);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_bufferTextures[0], 0);
    }
}




















