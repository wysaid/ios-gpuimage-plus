/*
* cgeMotionBlurAdjust.cpp
*
*  Created on: 2014-9-25
*/

#include "cgeMotionBlurAdjust.h"
#include "cgeMat.h"

const static char* const s_fshMotionBlurCurve = CGE_SHADER_STRING_PRECISION_H
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 uniform vec2 samplerStep;
 uniform vec2 blurNorm;
 uniform float samplerRadius;
 const int number = 10; // sum = number*2 + 1
 
 float random(vec2 seed)
{
    return fract(sin(dot(seed ,vec2(12.9898,78.233))) * 43758.5453);
}
 
 void main()
{
    vec4 src = texture2D(inputImageTexture, textureCoordinate);
    vec4 resultColor = vec4(0.0);
    float blurPixels = 0.0;
    float offset = random(textureCoordinate) - 0.5;
    
    vec2 arg = blurNorm * samplerStep * samplerRadius;
    
    for(int i = -number; i <= number; ++i)
    {
        float percent = (float(i) + offset) / float(number);
        float weight = 1.0 - abs(percent);
        vec2 coord = textureCoordinate + percent * arg;
        resultColor += texture2D(inputImageTexture, coord) * weight;
        blurPixels += weight;
    }
    
    vec4 color = resultColor / blurPixels;
    
    float factor = 0.1;
    float x = textureCoordinate.x;
    float PI = 3.141592653589793;
    float y = pow(2.0, -5.0 * (x + 0.3)) * sin(((x + 0.3) - factor / 3.0) * (0.7 * PI) / factor) + 0.18;
    y = y/3.0;
    
//    y =
    
    float po = 0.2;
    
    if(textureCoordinate.y < 1.0 - y - po){
        gl_FragColor = color;
        
    } else if (textureCoordinate.y < 1.0 - y){
        gl_FragColor = color * smoothstep(1.0 - y, 1.0 - y - po, textureCoordinate.y);
    } else {
        gl_FragColor = color * 0.0;;
    }
}
 );

const static char* const s_fshMotionBlur = CGE_SHADER_STRING_PRECISION_H
(
varying vec2 textureCoordinate;
uniform sampler2D inputImageTexture;
uniform vec2 samplerStep;
uniform vec2 blurNorm;
uniform float samplerRadius;
const int number = 10; // sum = number*2 + 1

float random(vec2 seed)
{
	return fract(sin(dot(seed ,vec2(12.9898,78.233))) * 43758.5453);
}

void main()
{
	vec4 src = texture2D(inputImageTexture, textureCoordinate);
// 	if(samplerRadius == 0.0)
// 	{
// 		gl_FragColor = vec4(src, 0.0);
// 		return;
// 	}
	vec4 resultColor = vec4(0.0);
	float blurPixels = 0.0;
    float offset = random(textureCoordinate) - 0.5;

	vec2 arg = blurNorm * samplerStep * samplerRadius;

	for(int i = -number; i <= number; ++i)
	{
		float percent = (float(i) + offset) / float(number);
		float weight = 1.0 - abs(percent);
		vec2 coord = textureCoordinate + percent * arg;
		resultColor += texture2D(inputImageTexture, coord) * weight;
		blurPixels += weight;
	}
	gl_FragColor = resultColor / blurPixels;
}
);

namespace CGE
{
	CGEConstString CGEMotionBlurFilter::paramSamplerRadiusName = "samplerRadius";
	CGEConstString CGEMotionBlurFilter::paramSamplerStepName = "samplerStep";
	CGEConstString CGEMotionBlurFilter::paramBlurNormName = "blurNorm";

	bool CGEMotionBlurFilter::init()
	{
		if(initShadersFromString(g_vshDefaultWithoutTexCoord, s_fshMotionBlur))
		{
			m_samplerRadius = 0;
			return true;
		}
		return false;
	}

	void CGEMotionBlurFilter::setSamplerRadius(float radius)
	{
		m_program.bind();
		m_program.sendUniformf(paramSamplerRadiusName, radius);
	}

	void CGEMotionBlurFilter::setAngle(float angle)
	{
		float radians = angle / 180.0f * M_PI;
		setRadians(radians);
	}

	void CGEMotionBlurFilter::setRadians(float radians)
	{
		m_blurNorm = Vec2f(cosf(radians), sinf(radians));
	}

	void CGEMotionBlurFilter::render2Texture(CGEImageHandlerInterface* handler, GLuint srcTexture, GLuint vertexBufferID)
	{
		const CGESizei& sz = handler->getOutputFBOSize();		

		m_program.bind();
		m_program.sendUniformf(paramSamplerStepName, 1.0f / sz.width, 1.0f / sz.height);

		// Pass one
		handler->setAsTarget();

		glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
		glEnableVertexAttribArray(0);
        glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, srcTexture);
		m_program.sendUniformf(paramBlurNormName, m_blurNorm[0], m_blurNorm[1]);
		glDrawArrays(GL_TRIANGLE_FAN, 0, 4);		
	}
    
    bool CGEMotionBlurCurveFilter::init()
    {
        if(initShadersFromString(g_vshDefaultWithoutTexCoord, s_fshMotionBlurCurve))
        {
            m_samplerRadius = 0;
            return true;
        }
        return false;
    }
}
