/*
 * cgeDynamicWaveFilter.h
 *
 *  Created on: 2016-8-12
 *      Author: Wang Yang
 */

#ifndef cgeMotionFlowFilter_h
#define cgeMotionFlowFilter_h

#include "cgeGLFunctions.h"
#include <list>

namespace CGE
{
    class TextureDrawer;
    
    class CGEMotionFlowFilter : public CGEImageFilterInterface
    {
    public:
        CGEMotionFlowFilter();
        ~CGEMotionFlowFilter();
        
        bool init();
        
        void setTotalFrames(int frames);
        void setFrameDelay(int delayFrame);
        
        void render2Texture(CGEImageHandlerInterface* handler, GLuint srcTexture, GLuint vertexBufferID);
        
    protected:
        
        virtual void pushFrame(GLuint texture);
        void clear();
        
    protected:
        
        static CGEConstString paramAlphaName;
        
        std::list<GLuint> m_frameTextures;
        std::vector<GLuint> m_totalFrameTextures;
        FrameBuffer m_framebuffer;
        TextureDrawer* m_drawer;
        int m_width, m_height;
        int m_totalFrames, m_delayFrames;
        int m_delayedFrames;
        
        float m_dAlpha;
        GLint m_alphaLoc;
    };
    
    class CGEMotionFlow2Filter : public CGEMotionFlowFilter
    {
    public:
        CGEMotionFlow2Filter();
        
//        void render2Texture(CGEImageHandlerInterface* handler, GLuint srcTexture, GLuint vertexBufferID);
        
    protected:
        void pushFrame(GLuint texture);
        
        float m_sizeScaling, m_dSizeScaling;
        float m_dsMost;
        
        bool m_continuouslyTrigger;
    };
    
    
    
    
}


#endif /* cgeMotionFlowFilter_h */
