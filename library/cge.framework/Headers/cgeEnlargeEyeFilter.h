/*
* cgeEnlargeEyeFilter.h
*
*  Created on: 2014-4-23
*      Author: Wang Yang
*/

#ifndef _CGE_ENLARGEEYE_H_
#define _CGE_ENLARGEEYE_H_

#include "cgeAdvancedEffectsCommon.h"
#include "cgeVec.h"

namespace CGE
{
	class CGEEnlargeEyeFilter : public CGEAdvancedEffectOneStepFilterHelper
	{
	public:
		
		bool init();

		void setEnlargeRadius(float radius); //Real radius counts by pixels.
		void setIntensity(float value); //Range: [-1.0, 1.0]
		void setCentralPosition(float x, float y); //Real position counts by pixels.

	protected:
		static CGEConstString paramRadiusName;
		static CGEConstString paramIntensityName;
		static CGEConstString paramCentralPosName;
	};
    
    class CGEEnlarge2EyesFilter : public CGEAdvancedEffectOneStepFilterHelper
    {
    public:
        bool init();
        
        void setEyeEnlargeRadius(float leftEyeRadius, float rightEyeRadius);
        void setIntensity(float value);
        void setEyePos(const Vec2f& left, const Vec2f& right);
        
    protected:
        static CGEConstString paramEyeRadiusName;
        static CGEConstString paramIntensityName;
        static CGEConstString paramLeftEyePosName;
        static CGEConstString paramRightEyePosName;
    };
    
    class CGEEnlarge2EyesAndMouthFilter : public CGEEnlarge2EyesFilter
    {
    public:
        bool init();
        
        void setMouthEnlargeRadius(float mouthRadius);
        
        void setMouthPos(const Vec2f& pos);
        
    protected:
        static CGEConstString paramMouthRadiusName;
        static CGEConstString paramMouthPosName;
    };

}

#endif