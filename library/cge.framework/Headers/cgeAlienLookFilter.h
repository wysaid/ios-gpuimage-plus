/* cgeAlienLookFilter.h
*
*  Created on: 2016-3-23
*      Author: Wang Yang
*/

#ifndef _CGE_ALIENLOOKFILTER_H_
#define _CGE_ALIENLOOKFILTER_H_

#include "cgeImageFilter.h"

namespace CGE
{
    class CGEAlienLookFilter : public CGEImageFilterInterface
    {
    public:
        
        bool init();

        void setIntensity(float value);

        // void render2Texture(CGEImageHandlerInterface* handler, GLuint srcTexture, GLuint vertexBufferID);

        void setImageSize(float width, float height);

        void updateKeyPoints(float leftEyeX, float leftEyeY, float rightEyeX, float rightEyeY, float mouthX, float mouthY);

    protected:
    	static CGEConstString paramLeftEye;
    	static CGEConstString paramRightEye;
    	static CGEConstString paramMouth;

    	GLint m_leftEyeLoc, m_rightEyeLoc, m_mouthLoc;
    };
}

#endif