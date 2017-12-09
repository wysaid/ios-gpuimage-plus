/*
* cgeSprite2d.cpp
*
*  Created on: 2014-9-9
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#ifndef _CGE_ONLY_FILTERS_

#include "cgeSprite2d.h"
#include "cgeGlobal.h"

#define LOG_FOR_LACKOF_FRAMES CGE_LOG_ERROR("Not enough frames!\n")

static CGEConstString s_vshSprite2d = CGE_SHADER_STRING(
//Range: [-1, 1]
attribute vec2 aPosition; 
varying vec2 vTextureCoord;
uniform mat4 spriteModelViewProjection;
uniform vec2 spriteHalfTexSize;

uniform float rotation;
uniform vec2 spriteScaling;
uniform vec2 spriteTranslation;
uniform vec2 spriteHotspot;
uniform vec2 canvasflip;
uniform vec2 spriteflip;
uniform float zIndex;

mat2 mat2ZRotation(float rad)
{
	float cosRad = cos(rad);
	float sinRad = sin(rad);
	return mat2(cosRad, sinRad, -sinRad, cosRad);//, 0.0, 0.0, 0.0, 1.0);
}

void main()
{
	vTextureCoord = (aPosition.xy * spriteflip + 1.0) / 2.0;
	vec2 hotspot = spriteHotspot * spriteHalfTexSize;
	vec2 pos = mat2ZRotation(rotation) * (aPosition * spriteHalfTexSize - hotspot) * spriteScaling + spriteTranslation;

	gl_Position = spriteModelViewProjection * vec4(pos, zIndex, 1.0);
	gl_Position.xy *= canvasflip;
});

static CGEConstString s_fshSprite2d = CGE_SHADER_STRING_PRECISION_M
(
varying vec2 vTextureCoord;
uniform sampler2D sTexture;
uniform float alpha;

void main()
{
	gl_FragColor = texture2D(sTexture, vTextureCoord);
)
#if CGE_TEXTURE_PREMULTIPLIED
	"gl_FragColor *= alpha;"
#else
	"gl_FragColor.a *= alpha;"
#endif
"}";

//static CGEConstString s_vshSprite2dExt = CGE_SHADER_STRING
//(
//attribute vec2 aPosition; 
//varying vec2 vTextureCoord;
//uniform mat4 spriteModelViewProjection;
//uniform vec2 spriteHalfTexSize;
//
//uniform float rotation;
//uniform vec2 spriteScaling;
//uniform vec2 spriteTranslation;
//uniform vec2 spriteHotspot;
//uniform vec2 canvasflip;
//uniform vec2 spriteflip;
//uniform float zIndex;
//
//uniform vec2 scaleRatio; //缩放比， 用来实现在整张画布上循环贴图。
//
//mat2 mat2ZRotation(float rad)
//{
//	float cosRad = cos(rad);
//	float sinRad = sin(rad);
//	return mat2(cosRad, sinRad, -sinRad, cosRad);//, 0.0, 0.0, 0.0, 1.0);
//}
//
//void main()
//{
//	vTextureCoord = (aPosition.xy * spriteflip + 1.0) / 2.0 * scaleRatio;
//	vec2 hotspot = spriteHotspot * spriteHalfTexSize;
//	vec2 pos = mat2ZRotation(rotation) * (aPosition * spriteHalfTexSize - hotspot) * spriteScaling + spriteTranslation;
//
//	gl_Position = spriteModelViewProjection * vec4(pos, zIndex, 1.0);
//	gl_Position.xy *= canvasflip;
//}
//);

//static CGEConstString s_fshSprite2dExt = CGE_SHADER_STRING_PRECISION_M
//(
// varying vec2 vTextureCoord;
// uniform sampler2D sTexture;
// uniform float alpha;
// uniform vec3 blendColor;
//
//void main()
//{
//    gl_FragColor = texture2D(sTexture, fract(vTextureCoord));
//	gl_FragColor.rgb *= blendColor;
//)
//#if CGE_TEXTURE_PREMULTIPLIED
//	"gl_FragColor *= alpha;"
//#else
//	"gl_FragColor.a *= alpha;"
//#endif
//"}";

static CGEConstString s_vshSprite2dInterChange = CGE_SHADER_STRING(
//Range: [-1, 1]
attribute vec2 aPosition; 
varying vec2 vTextureCoord;
uniform mat4 spriteModelViewProjection;
uniform vec2 spriteHalfTexSize;

uniform float rotation;
uniform vec2 spriteScaling;
uniform vec2 spriteTranslation;
uniform vec2 spriteHotspot;
uniform vec2 canvasflip;
uniform vec2 spriteflip;
uniform float zIndex;

//const vec4 viewArea = vec4(0.0,0.0,1.0,1.0); //定义纹理可视区域， xy取值范围[0, 1), zw取值范围: (0, 1]
uniform vec4 viewArea;
                                                                   
mat2 mat2ZRotation(float rad)
{
	float cosRad = cos(rad);
	float sinRad = sin(rad);
	return mat2(cosRad, sinRad, -sinRad, cosRad);//, 0.0, 0.0, 0.0, 1.0);
}

void main()
{
	vTextureCoord = ((aPosition.xy * spriteflip + 1.0) / 2.0) * viewArea.zw + viewArea.xy;
	vec2 texSize = spriteHalfTexSize * viewArea.zw; //将整个图片缩放至view区域的大小
	vec2 hotspot = spriteHotspot * texSize;
	vec2 pos = mat2ZRotation(rotation) * ((aPosition * texSize - hotspot) * spriteScaling) + spriteTranslation;

	gl_Position = spriteModelViewProjection * vec4(pos, zIndex, 1.0);
	gl_Position.xy *= canvasflip;
});

//////////////////////////////////////////////////////////////////////////

//static CGEConstString s_vshSprite2dWith3dSpace = CGE_SHADER_STRING(
////Range: [-1, 1]
//attribute vec2 aPosition; 
//varying vec2 vTextureCoord;
//uniform mat4 spriteModelViewProjection;
//uniform vec2 spriteHalfTexSize;
//
//uniform mat3 rotation;
//uniform vec2 spriteScaling;
//uniform vec2 spriteTranslation;
//uniform vec3 spriteHotspot;
//uniform vec2 canvasflip;
//uniform vec2 spriteflip;
//uniform float zIndex;
//
//void main()
//{
//	vTextureCoord = (aPosition.xy * spriteflip + 1.0) / 2.0;
//	vec3 halfTexSize = vec3(spriteHalfTexSize, max(spriteHalfTexSize.x, spriteHalfTexSize.y));
//	vec3 hotspot = spriteHotspot * halfTexSize;
//	vec3 pos = rotation * (vec3(aPosition, 0.0) * halfTexSize - hotspot) + hotspot;
//	pos.xy *= spriteScaling;
//	pos.xy += spriteTranslation - spriteScaling * hotspot.xy;
//	pos.z += zIndex - hotspot.z;
//	gl_Position = spriteModelViewProjection * vec4(pos, 1.0);
//	gl_Position.xy *= canvasflip;
//});


//////////////////////////////////////////////////////////////////////////
//
//static CGEConstString s_vshBlank = CGE_SHADER_STRING
//(
//attribute vec4 aPosition; 
//
//uniform vec2 blankflip;
//
//void main()
//{
//	gl_Position = aPosition;
//	gl_Position.xy *= blankflip;
//}
//);
//
//static CGEConstString s_fshBlank = CGE_SHADER_STRING_PRECISION_L
//(
//void main()
//{
//	gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
//}
//);

//////////////////////////////////////////////////////////////////////////

static CGEConstString s_fshSprite2dWithSpecialAlpha = CGE_SHADER_STRING_PRECISION_M
(
varying vec2 vTextureCoord;
uniform sampler2D sTexture;
uniform sampler2D sAlphaTex;
uniform float alpha;
uniform vec2 alphaFactor;

void main()
{
	vec3 alphaGradient = texture2D(sAlphaTex, vTextureCoord).rgb;
    alphaGradient = smoothstep(vec3(alphaFactor.x), vec3(alphaFactor.y), alphaGradient);
    float lum = dot(alphaGradient, vec3(0.299, 0.587, 0.114));
	gl_FragColor = texture2D(sTexture, vTextureCoord) * vec4(alphaGradient, lum);
    
#if CGE_TEXTURE_PREMULTIPLIED
	gl_FragColor *= alpha;
#else
	gl_FragColor.a *= alpha;
#endif
});

//////////////////////////////////////////////////////////////////////////

namespace CGE
{
	CGEConstString SpriteInterface2d::paramAttribPositionName = "aPosition";
	CGEConstString SpriteInterface2d::paramProjectionMatrixName = "spriteModelViewProjection";
	CGEConstString SpriteInterface2d::paramHalfTexSizeName = "spriteHalfTexSize";
	CGEConstString SpriteInterface2d::paramRotationName = "rotation";
	CGEConstString SpriteInterface2d::paramScalingName = "spriteScaling";
	CGEConstString SpriteInterface2d::paramTranslationName = "spriteTranslation";
	CGEConstString SpriteInterface2d::paramHotspotName = "spriteHotspot";
	CGEConstString SpriteInterface2d::paramAlphaName = "alpha";
	CGEConstString SpriteInterface2d::paramZIndexName = "zIndex";
	CGEConstString SpriteInterface2d::paramTextureName = "sTexture";
	CGEConstString SpriteInterface2d::paramFilpCanvasName = "canvasflip";
	CGEConstString SpriteInterface2d::paramFlipSpriteName = "spriteflip";
	CGEConstString SpriteInterface2d::paramBlendColorName = "blendColor";

	SpriteInterface2d::SpriteInterface2d() : m_pos(0.0f, 0.0f), m_scaling(1.0f, 1.0f), m_hotspot(0.0f, 0.0f), m_rotation(0.0f), m_alpha(1.0f), m_zIndex(0.0f)
	{		
	}

	//////////////////////////////////////////////////////////////////////////

	Sprite2d::Sprite2d(const SharedTexture& texture) : SpriteInterface2d(), m_texture(texture) {}
	Sprite2d::Sprite2d() { CGEAssert(0); } //兼容性接口

    Sprite2d::~Sprite2d() {}

	CGEConstString Sprite2d::getVertexString()
	{
		return s_vshSprite2d;
	}

	CGEConstString Sprite2d::getFragmentString()
	{
		return s_fshSprite2d;
	}

	bool Sprite2d::_initProgram()
	{
		m_posAttribLocation = 0;
		m_program.bindAttribLocation(paramAttribPositionName, m_posAttribLocation);

		if(!m_program.initWithShaderStrings(getVertexString(), getFragmentString()))
		{
			CGE_LOG_ERROR("Sprite2d - init program failed! ProgramID : %d\n", m_program.programID());
			return false;
		}

		_initProgramVars();
		cgeCheckGLError("Sprite2d - initProgram");
		return true;
	}

	void Sprite2d::_initProgramVars()
	{
		m_program.bind();

		m_projectionLocation = m_program.uniformLocation(paramProjectionMatrixName);
		m_halfTexLocation = m_program.uniformLocation(paramHalfTexSizeName);
		m_rotationLocation = m_program.uniformLocation(paramRotationName);
		m_scalingLocation = m_program.uniformLocation(paramScalingName);
		m_translationLocation = m_program.uniformLocation(paramTranslationName);
		m_hotspotLocation = m_program.uniformLocation(paramHotspotName);
		m_alphaLocation = m_program.uniformLocation(paramAlphaName);
		m_zIndexLocation = m_program.uniformLocation(paramZIndexName);
		m_textureLocation = m_program.uniformLocation(paramTextureName);
		m_canvasFlipLocation = m_program.uniformLocation(paramFilpCanvasName);
		m_spriteFilpLocation = m_program.uniformLocation(paramFlipSpriteName);

		glUniform1f(m_alphaLocation, m_alpha);
		glUniform2f(m_halfTexLocation, m_texture.width / 2.0f, m_texture.height / 2.0f);
		glUniformMatrix4fv(m_projectionLocation, 1, false, sOrthoProjectionMatrix[0]);
		glUniform2f(m_scalingLocation, m_scaling[0], m_scaling[1]);

		setCanvasFlip(sCanvasFlipX, sCanvasFlipY);
		setSpriteFlip(sSpriteFlipX, sSpriteFlipY);

//		glUniform1i(m_textureLocation, 0); 使用 uniform 变量 默认值 0
//		glUniform2f(m_hotspotLocation, m_hotspot[0], m_hotspot[1]); 
//		glUniform2f(m_translationLocation, m_pos[0], m_pos[1]); 
//		glUniform1f(m_rotationLocation, m_rotation);
//		glUniform1f(m_zIndexLocation, m_zIndex);
		
	}

	void Sprite2d::setTexture(const SharedTexture& tex)
	{
		m_texture = tex;
		m_program.bind();
		glUniform2f(m_halfTexLocation, tex.width / 2.0f, tex.height / 2.0f);
	}

	void Sprite2d::render()
	{
		m_program.bind();
  		glUniform2f(m_translationLocation, m_pos[0], m_pos[1]);
		glUniform2f(m_scalingLocation, m_scaling[0], m_scaling[1]);
		glUniform1f(m_rotationLocation, m_rotation);

		_drawFunc();
	}

	void Sprite2d::_drawFunc()
	{
#if _CGE_USE_GLOBAL_GL_CACHE_
		glBindBuffer(GL_ARRAY_BUFFER, CGEGlobalConfig::sVertexBufferCommon);
		glEnableVertexAttribArray(m_posAttribLocation);
		glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, 0);
#else
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glEnableVertexAttribArray(m_posAttribLocation);
        glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, CGEGlobalConfig::sVertexDataCommon);
#endif
		m_texture.bindToIndex(0);
		glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	}

	//////////////////////////////////////////////////////////////////////////

	CGEConstString Sprite2dWithAlphaGradient::paramAlphaFactorName = "alphaFactor";
	CGEConstString Sprite2dWithAlphaGradient::paramTexAlphaName = "sAlphaTex";

	CGEConstString Sprite2dWithAlphaGradient::getVertexString()
	{
		return s_vshSprite2d;
	}

	CGEConstString Sprite2dWithAlphaGradient::getFragmentString()
	{
		return s_fshSprite2dWithSpecialAlpha;
	}

	Sprite2dWithAlphaGradient::Sprite2dWithAlphaGradient(const SharedTexture& texture) : Sprite2d(texture) { _initProgram(); }
	Sprite2dWithAlphaGradient::~Sprite2dWithAlphaGradient() {}

	bool Sprite2dWithAlphaGradient::_initProgram()
	{
		m_posAttribLocation = 0;
		m_program.bindAttribLocation(paramAttribPositionName, m_posAttribLocation);

		if(!m_program.initWithShaderStrings(getVertexString(), getFragmentString()))
		{
			CGE_LOG_ERROR("Sprite2d - init program failed! ProgramID : %d\n", m_program.programID());
			return false;
		}

		_initProgramVars();
		m_texAlphaLocation = m_program.uniformLocation(paramTexAlphaName);
		m_alphaFactorLocation = m_program.uniformLocation(paramAlphaFactorName);
		cgeCheckGLError("Sprite2dWithSpecialAlpha - initProgram");
		return true;
	}

	void Sprite2dWithAlphaGradient::setAlphaFactor(float start, float end)
	{
		m_program.bind();
		glUniform2f(m_alphaFactorLocation, start, end);
	}

	void Sprite2dWithAlphaGradient::_drawFunc()
	{
#if _CGE_USE_GLOBAL_GL_CACHE_
		glBindBuffer(GL_ARRAY_BUFFER, CGEGlobalConfig::sVertexBufferCommon);
		glEnableVertexAttribArray(m_posAttribLocation);
		glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, 0);
#else
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glEnableVertexAttribArray(m_posAttribLocation);
        glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, CGEGlobalConfig::sVertexDataCommon);
#endif
		m_texture.bindToIndex(0);
//		glUniform1i(m_textureLocation, 0);
		CGEAssert(m_texAlpha.texID() != 0);
		m_texAlpha.bindToIndex(1);
		glUniform1i(m_texAlphaLocation, 1);
		glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	}

	//////////////////////////////////////////////////////////////////////////

	CGEConstString Sprite2dInterChange::paramViewAreaName = "viewArea";

	CGEConstString Sprite2dInterChange::getVertexString()
	{
		return s_vshSprite2dInterChange;
	}

	CGEConstString Sprite2dInterChange::getFragmentString()
	{
		return s_fshSprite2d;
	}

	Sprite2dInterChange::Sprite2dInterChange(const SharedTexture& texture) : Sprite2d(texture) {}
	Sprite2dInterChange::~Sprite2dInterChange() { }

	bool Sprite2dInterChange::_initProgram()
	{
		m_posAttribLocation = 0;
		m_program.bindAttribLocation(paramAttribPositionName, m_posAttribLocation);

		if(!m_program.initWithShaderStrings(getVertexString(), getFragmentString()))
		{
			CGE_LOG_ERROR("Sprite2dInterChange - init program failed! ProgramID : %d\n", m_program.programID());
			return false;
		}

		_initProgramVars();

		m_viewAreaLocation = m_program.uniformLocation(paramViewAreaName);
		glUniform4f(m_viewAreaLocation, 0.0f, 0.0f, 1.0f, 1.0f); //默认使用 full 辨率.

		cgeCheckGLError("Sprite2dInterChange - initProgram");
		return true;
    }

// 	void Sprite2dInterChange::_drawFunc()
// 	{
// 
// 	}

	//////////////////////////////////////////////////////////////////////////

	void Sprite2dInterChangeExt::firstFrame()
	{
		if(m_vecFrames.empty())
		{
            LOG_FOR_LACKOF_FRAMES;
			return ;
		}
		m_frameIndex = 0;
        m_deltaAccum = 0.0;
		setViewArea(m_vecFrames[0]);
	}

	void Sprite2dInterChangeExt::nextFrame(unsigned int offset)
	{
		if(m_vecFrames.empty())
		{
            LOG_FOR_LACKOF_FRAMES;
			return ;
		}

		m_frameIndex += offset;

		if(m_frameIndex >= m_vecFrames.size())
		{
			if(m_shouldLoop)
				m_frameIndex = m_frameIndex % m_vecFrames.size();
			else
				m_frameIndex = (int)m_vecFrames.size() - 1;
		}		
		
		setViewArea(m_vecFrames[m_frameIndex]);
	}

	void Sprite2dInterChangeExt::updateFrame(double dt)
	{
		m_deltaAccum += dt;
		if(m_deltaAccum > m_deltaTime)
		{
			unsigned int cnt = floor(m_deltaAccum / m_deltaTime);
			nextFrame(cnt);
			m_deltaAccum -= m_deltaTime * cnt;
		}
	}

	void Sprite2dInterChangeExt::updateByTime(double t)
	{
		updateFrame(t - m_lastTime);
		m_lastTime = t;
	}

	void Sprite2dInterChangeExt::flushViewArea()
	{
		if(m_vecFrames.empty())
		{
			CGE_LOG_ERROR("No view area to set!");
			return ;
		}
		setViewArea(m_vecFrames[m_frameIndex % m_vecFrames.size()]);
	}

	void Sprite2dInterChangeExt::_drawFunc()
	{
#if _CGE_USE_GLOBAL_GL_CACHE_
		glBindBuffer(GL_ARRAY_BUFFER, CGEGlobalConfig::sVertexBufferCommon);
		glEnableVertexAttribArray(m_posAttribLocation);
		glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, 0);
#else
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glEnableVertexAttribArray(m_posAttribLocation);
        glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, CGEGlobalConfig::sVertexDataCommon);
#endif
		m_texture.bindToIndex(0);

		if(m_blendMode != CGEGLOBAL_BLEND_NONE)
			cgeSetGlobalBlendMode(m_blendMode);

		glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

		if(m_blendMode != CGEGLOBAL_BLEND_NONE)
			cgeSetGlobalBlendMode(CGEGLOBAL_BLEND_ALPHA);
	}
    
    ///////////////////////////////////////////
    
    Sprite2dInterChangeMultiple::~Sprite2dInterChangeMultiple()
    {
        m_texture.forceRelease(false);
        _clearTextures();
    }
    
    void Sprite2dInterChangeMultiple::nextFrame(unsigned int offset)
    {
        if(m_vecFrames.empty())
        {
            LOG_FOR_LACKOF_FRAMES;
            return;
        }
        
        m_frameIndex += offset;
        
        if(m_frameIndex >= m_vecFrames.size())
        {
            if(m_shouldLoop)
                m_frameIndex = m_frameIndex % m_vecFrames.size();
            else m_frameIndex = (int)m_vecFrames.size() - 1;
        }
        
        _setToFrame(m_vecFrames[m_frameIndex]);
    }
    
    void Sprite2dInterChangeMultiple::updateFrame(double dt)
    {
        m_deltaAccum += dt;
        if(m_deltaAccum > m_deltaTime)
        {
            unsigned cnt = floor(m_deltaAccum / m_deltaTime);
            nextFrame(cnt);
            m_deltaAccum -= m_deltaTime * cnt;
        }
    }
    
    void Sprite2dInterChangeMultiple::updateByTime(double t)
    {
        updateFrame(t - m_lastTime);
        m_lastTime = t;
    }
    
    void Sprite2dInterChangeMultiple::_setToFrame(const SpriteFrame &frame)
    {
        Sprite2dInterChange::setViewArea(frame.frame);
        m_texture.forceAssignTextureID(frame.texture);
    }
    
    void Sprite2dInterChangeMultiple::jumpToFrame(int frameIndex)
    {
        if(m_vecFrames.empty())
        {
            LOG_FOR_LACKOF_FRAMES;
            return ;
        }
        
        m_frameIndex = frameIndex;
        m_deltaAccum = 0.0;

		if(m_frameIndex >= m_vecFrames.size())
			m_frameIndex = (GLuint)m_vecFrames.size() - 1;
        _setToFrame(m_vecFrames[m_frameIndex]);
    }
    
    void Sprite2dInterChangeMultiple::jumpToLastFrame()
    {
        if(!m_vecFrames.empty())
            m_frameIndex = (GLuint)m_vecFrames.size() - 1;
    }
    
    void Sprite2dInterChangeMultiple::setFrameTextures(const std::vector<FrameTexture> &vec)
    {
        _clearTextures();
        m_vecTextures = vec;
        _calcFrames();
    }
    
    void Sprite2dInterChangeMultiple::setFrameTextures(FrameTexture *frames, int count)
    {
        setFrameTextures(std::vector<FrameTexture>(frames, frames + count));
    }
    
    void Sprite2dInterChangeMultiple::_clearTextures()
    {
        for(auto& frame : m_vecTextures)
        {
            glDeleteTextures(1, &frame.textureID);
        }
        m_vecTextures.clear();
        m_vecFrames.clear();
    }
    
    void Sprite2dInterChangeMultiple::_calcFrames()
    {
        m_vecFrames.clear();
        
        SpriteFrame frame;
//        int frameIndex = 0;
        
        for(auto& tex : m_vecTextures)
        {
            int total = tex.col * tex.row;
            float frameWidth = 1.0f / tex.col;
            float frameHeight = 1.0f / tex.row;
            
            if(tex.count < total)
                total = tex.count;
            
            for(int i = 0; i != total; ++i)
            {
                frame.texture = tex.textureID;
                frame.frame[0] = (i % tex.col) * frameWidth;
                frame.frame[1] = (i / tex.col) * frameHeight;
                frame.frame[2] = frameWidth;
                frame.frame[3] = frameHeight;
                
                m_vecFrames.push_back(frame);
            }
            
//            frameIndex += tex.count;
        }
        
    }
    

	//////////////////////////////////////////////////////////////////////////
    
    Sprite2dSequence::~Sprite2dSequence()
    {
        if(!m_frameTextures.empty())
            glDeleteTextures((int)m_frameTextures.size(), m_frameTextures.data());
        
        m_frameTextures.clear();
        m_texture.forceRelease(false);
    }
    
    void Sprite2dSequence::firstFrame()
    {
        m_frameIndex = 0;
        m_deltaAccum = 0.0;
    }
    
    void Sprite2dSequence::nextFrame(unsigned int offset)
    {
        m_frameIndex += offset;
        if(m_frameIndex >= m_frameTextures.size())
        {
            if(m_shouldLoop)
            {
                m_frameIndex = m_frameIndex % m_frameTextures.size();
            }
            else
            {
                m_frameIndex = (unsigned)m_frameTextures.size() - 1;
                m_canUpdate = false;
            }
        }
    }
    
    void Sprite2dSequence::updateFrame(double dt)
    {
        if(m_canUpdate)
        {
            m_deltaAccum += dt;
            if(m_deltaAccum > m_deltaTime)
            {
                unsigned int cnt = floor(m_deltaAccum / m_deltaTime);
                nextFrame(cnt);
                m_deltaAccum -= m_deltaTime * cnt;
            }
        }
    }
    
    void Sprite2dSequence::updateByTime(double t)
    {
        updateFrame(t - m_lastTime);
        m_lastTime = t;
    }
    
    void Sprite2dSequence::setFPS(double fps, bool useSec)
    {
        m_deltaTime = (useSec ? 1.0 : 1000.0) / fps;
    }
    
    void Sprite2dSequence::_drawFunc()
    {
#if _CGE_USE_GLOBAL_GL_CACHE_
        glBindBuffer(GL_ARRAY_BUFFER, CGEGlobalConfig::sVertexBufferCommon);
        glEnableVertexAttribArray(m_posAttribLocation);
        glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, 0);
#else
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glEnableVertexAttribArray(m_posAttribLocation);
        glVertexAttribPointer(m_posAttribLocation, 2, GL_FLOAT, false, 0, CGEGlobalConfig::sVertexDataCommon);
#endif
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, m_frameTextures[m_frameIndex]);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    }
    
    bool Sprite2dSequence::isLastFrame()
    {
        return m_frameIndex >= m_frameTextures.size() - 1;
    }
    
    void Sprite2dSequence::setToLastFrame()
    {
        m_frameIndex = (unsigned int)m_frameTextures.size() - 1;
    }
}

#endif
