//
//  cgeSoulStuffFilter.h
//  cgeStatic
//
//  Created by Yang Wang on 2017/3/27.
//  Mail: admin@wysaid.org
//  Copyright © 2017年 wysaid. All rights reserved.
//

#ifndef cgeSoulStuffFilter_h
#define cgeSoulStuffFilter_h

#include "cgeGLFunctions.h"
#include "cgeVec.h"

namespace CGE
{
    class CGESoulStuffFilter : public CGEImageFilterInterface
    {
    public:
        CGESoulStuffFilter();
        ~CGESoulStuffFilter();
        
        bool init();
        
        void render2Texture(CGEImageHandlerInterface* handler, GLuint srcTexture, GLuint vertexBufferID);
        
        void trigger(float ds, float most);
        
        void setSoulStuffPos(float x, float y);
        
        inline void enableContinuouslyTrigger(bool continuouslyTrigger) { m_continuouslyTrigger = continuouslyTrigger; }
        
    protected:
        static CGEConstString paramSoulStuffPos;
        static CGEConstString paramSoulStuffScaling;
        
        GLint m_soulStuffPosLoc, m_soulStuffScalingLoc;
        float m_sizeScaling;
        float m_dSizeScaling;
        float m_dsMost;
        
        Vec2f m_pos;
        
        bool m_continuouslyTrigger;
    };
}

#endif /* cgeSoulStuffFilter_h */
