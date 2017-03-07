//
//  cgeDistortionFilter.h
//  cgeStatic
//
//  Created by wangyang on 16/6/1.
//  Copyright © 2016年 wysaid. All rights reserved.
//

#ifndef _cgeDistortionFilter_h_
#define _cgeDistortionFilter_h_

#include "cgeImageFilter.h"

namespace CGE
{
    class CGEDistortionFilter : public CGEImageFilterInterface
    {
    public:
        CGEDistortionFilter();
        ~CGEDistortionFilter();
        
        bool initDistortionBloatWrinkle();
        bool initDistortionForward();
        
        void setIntensity(float value);
        void setSteps(float x, float y);
        void setPointParams(float pointX, float pointY, float radius, float intensity = -1.0f);
        
        void setForwardParams(float point1X, float point1Y, float point2X, float point2Y, float radius, float intensity = -1.0f);
        
    protected:
        
        bool _setup(CGEConstString vsh, CGEConstString fsh);
        
        GLint m_intensityLoc;
        GLint m_radiusLoc;
        GLint m_stepsLoc;
        GLint m_keyPointLoc;
        GLint m_keyPoint2Loc;
        GLint m_equationLoc;
        
        float m_intensity;
    };
}


#endif
