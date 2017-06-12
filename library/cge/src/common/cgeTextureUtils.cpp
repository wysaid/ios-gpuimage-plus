/*
* cgeTextureUtils.cpp
*
*  Created on: 2015-7-29
*      Author: Wang Yang
*/

//#include <GLES2/gl2.h>
#include <cmath>
#include "cgeTextureUtils.h"
#include "cgeGlobal.h"
#include "cgeMat.h"

static CGEConstString s_vsh = CGE_SHADER_STRING(
attribute vec2 vPosition;
varying vec2 texCoord;
uniform mat2 rotation;
uniform vec2 flipScale;
void main()
{
   gl_Position = vec4(vPosition, 0.0, 1.0);
   texCoord = flipScale * (vPosition / 2.0 * rotation) + 0.5;
});

static CGEConstString s_fsh = CGE_SHADER_STRING_PRECISION_M(
varying vec2 texCoord;
uniform sampler2D inputImageTexture;
void main()
{
   gl_FragColor = texture2D(inputImageTexture, texCoord);
	// gl_FragColor = vec4(texCoord, 0.0, 1.0);
});

static CGEConstString s_vshMask = CGE_SHADER_STRING(
attribute vec2 vPosition;
varying vec2 texCoord;
varying vec2 maskCoord;

uniform mat2 texRotation;
uniform vec2 texFlipScale;

uniform mat2 maskRotation;
uniform vec2 maskFlipScale;

void main()
{
   gl_Position = vec4(vPosition, 0.0, 1.0);
   texCoord = texFlipScale * (vPosition / 2.0 * texRotation) + 0.5;
   //如果mask的大小与source 不一致， 需要进行flipscale 达到一致
   maskCoord = maskFlipScale * (vPosition / 2.0 * maskRotation) + 0.5;
});


static CGEConstString s_fshMask = CGE_SHADER_STRING_PRECISION_M(
varying vec2 texCoord;
varying vec2 maskCoord;
uniform sampler2D inputImageTexture;
uniform sampler2D maskTexture;
void main()
{
   gl_FragColor = texture2D(inputImageTexture, texCoord);
   
   //mask一般为单通道

   //不预乘
   gl_FragColor *= texture2D(maskTexture, maskCoord);

   // 预乘
   // vec4 maskColor = texture2D(maskTexture, maskCoord);
   // maskColor.rgb *= maskColor.a;
   // gl_FragColor *= maskColor;
});

#ifdef GL_TEXTURE_EXTERNAL_OES

static CGEConstString s_vshExternal_OES = CGE_SHADER_STRING(
attribute vec2 vPosition;
varying vec2 texCoord;
uniform mat4 transform;
uniform mat2 rotation;
uniform vec2 flipScale;
void main()
{
   gl_Position = vec4(vPosition, 0.0, 1.0);
   vec2 coord = flipScale * (vPosition / 2.0 * rotation) + 0.5;
   texCoord = (transform * vec4(coord, 0.0, 1.0)).xy;
});

static CGEConstString s_fshExternal_OES =
"#extension GL_OES_EGL_image_external : require\n"
CGE_SHADER_STRING_PRECISION_M(
varying vec2 texCoord;
uniform samplerExternalOES inputImageTexture;
void main()
{
   gl_FragColor = texture2D(inputImageTexture, texCoord);
});

#endif

CGEConstString s_fshYUVConvert = CGE_SHADER_STRING_PRECISION_M
(
 varying vec2 texCoord;
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 void main()
 {
     vec3 yuv;
     vec3 rgb;
     yuv.x = texture2D(luminanceTexture, texCoord).r;
     yuv.yz = texture2D(chrominanceTexture, texCoord).rg - vec2(0.5, 0.5);
//     rgb = mat3(1.0, 1.0, 1.0,
//                0.0, -.21482, 2.12798,
//                1.28033, -.38059, 0.0) * yuv;
     
     rgb = mat3(1.0, 1.0, 1.0,
                0.0, -0.18732, 1.8556,
                1.57481, -0.46813, 0.0) * yuv;
     
     gl_FragColor = vec4(rgb, 1.0);
 }
 );

namespace CGE
{

	CGEConstString TextureDrawer::getFragmentShaderString()
	{
		return s_fsh;
	}

	CGEConstString TextureDrawer::getVertexShaderString()
	{
		return s_vsh;
	}
    
    TextureDrawer::~TextureDrawer()
    {
        glDeleteBuffers(1, &m_vertBuffer);
    }

	bool TextureDrawer::init()
	{
        return initWithShaderString(getVertexShaderString(), getFragmentShaderString());
	}
    
    bool TextureDrawer::initWithShaderString(CGEConstString vsh, CGEConstString fsh)
    {
        glGenBuffers(1, &m_vertBuffer);
        if(m_vertBuffer == 0)
            return false;
        glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(CGEGlobalConfig::sVertexDataCommon), CGEGlobalConfig::sVertexDataCommon, GL_STATIC_DRAW);
        
        m_program.bindAttribLocation("vPosition", 0);
        if(!m_program.initWithShaderStrings(vsh, fsh))
        {
            return false;
        }
        
        m_program.bind();
        m_rotLoc = m_program.uniformLocation("rotation");
        m_flipScaleLoc = m_program.uniformLocation("flipScale");
        if(m_rotLoc < 0 || m_flipScaleLoc < 0)
        {
            CGE_LOG_ERROR("TextureDrawer program init error...");
        }
        setRotation(0.0f);
        setFlipScale(1.0f, 1.0f);
        return true;
    }

	void TextureDrawer::drawTexture(GLuint src)
	{
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, src);

		glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
		glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, 0);

        m_program.bind();
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	}

	void TextureDrawer::setRotation(float rad)
	{
		_rotate(m_rotLoc, rad);
	}

	void TextureDrawer::setFlipScale(float x, float y)
	{
		m_program.bind();
		glUniform2f(m_flipScaleLoc, x, y);
	}

	void TextureDrawer::bindVertexBuffer()
	{
		glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
	}

	void TextureDrawer::_rotate(GLint location, float rad)
	{
		float cosRad = cosf(rad);
		float sinRad = sinf(rad);
		float mat2[] = {
			cosRad, sinRad,
			-sinRad, cosRad
		};

		m_program.bind();
		glUniformMatrix2fv(location, 1, GL_FALSE, mat2);
	}

	///////////////////////////////////////////////////////////////
    
    TextureDrawerExt::~TextureDrawerExt()
    {
        
    }

	void TextureDrawerExt::drawTexture2Texture(GLuint src, GLuint dst)
	{
		assert(src != 0 && dst != 0);
		m_framebuffer.bindTexture2D(dst);
		TextureDrawer::drawTexture(src);
	}

	void TextureDrawerExt::bindTextureDst(GLuint dst, int width, int height)
	{
		m_framebuffer.bindTexture2D(dst);
		m_texSize.set(width, height);
	}


	void TextureDrawerExt::drawTexture2Buffer(GLuint src, bool fullSize)
	{
		m_framebuffer.bind();
		if(fullSize)
			glViewport(0, 0, m_texSize.width, m_texSize.height);
		TextureDrawer::drawTexture(src);
	}	

	///////////////////////////////////////////////////////////////
    
    TextureDrawerWithMask::~TextureDrawerWithMask()
    {
        glDeleteTextures(1, &m_maskTexture);
    }

	bool TextureDrawerWithMask::init()
	{
		glGenBuffers(1, &m_vertBuffer);
		if(m_vertBuffer == 0)
			return false;
		glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
		glBufferData(GL_ARRAY_BUFFER, sizeof(CGEGlobalConfig::sVertexDataCommon), CGEGlobalConfig::sVertexDataCommon, GL_STATIC_DRAW);

//		CGE_LOG_INFO("TextureDrawer- program id: %d", m_program.programID());

		m_program.bindAttribLocation("vPosition", 0);
		if(!m_program.initWithShaderStrings(s_vshMask, s_fshMask))
		{
			return false;
		}

		m_program.bind();
		m_rotLoc = m_program.uniformLocation("texRotation");
		m_flipScaleLoc = m_program.uniformLocation("texFlipScale");

		m_maskRotLoc = m_program.uniformLocation("maskRotation");
		m_maskFlipScaleLoc = m_program.uniformLocation("maskFlipScale");

		m_program.sendUniformi("inputImageTexture", 0);
		m_program.sendUniformi("maskTexture", 1);

		if(m_rotLoc < 0 || m_flipScaleLoc < 0 ||
			m_maskRotLoc < 0 || m_maskFlipScaleLoc < 0)
		{
			CGE_LOG_ERROR("TextureDrawer program init error...");
		}
		setRotation(0.0f);
		setFlipScale(1.0f, 1.0f);
		setMaskRotation(0.0f);
		setMaskFlipScale(1.0, 1.0f);
		m_maskTexture = 0;
		return true;
	}

	void TextureDrawerWithMask::setMaskRotation(float rad)
	{
		_rotate(m_maskRotLoc, rad);
	}

	void TextureDrawerWithMask::setMaskFlipScale(float x, float y)
	{
		m_program.bind();
		glUniform2f(m_maskFlipScaleLoc, x, y);
	}

	void TextureDrawerWithMask::drawTexture(GLuint src)
	{
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, m_maskTexture);

		TextureDrawer::drawTexture(src);
	}

	void TextureDrawerWithMask::setMaskTexture(GLuint maskTexture)
	{
		if(maskTexture == m_maskTexture)
			return;

		glDeleteTextures(1, &m_maskTexture);
		m_maskTexture = maskTexture;
	}

///////////////////////////////////////////////////////////////
#ifdef GL_TEXTURE_EXTERNAL_OES

	CGEConstString TextureDrawer4ExtOES::getFragmentShaderString()
	{
		return s_fshExternal_OES;
	}
	CGEConstString TextureDrawer4ExtOES::getVertexShaderString()
	{
		return s_vshExternal_OES;
	}

	bool TextureDrawer4ExtOES::init()
	{
		TextureDrawer::init();
		m_program.bind();
		m_transformLoc = m_program.uniformLocation("transform");
		CGE::Mat4 mat4 = CGE::Mat4::makeIdentity();
		setTransform(mat4.data[0]);
		return true;
	}

	void TextureDrawer4ExtOES::setTransform(float* mat16)
	{
		m_program.bind();
		glUniformMatrix4fv(m_transformLoc, 1, GL_FALSE, mat16);
	}

	void TextureDrawer4ExtOES::drawTexture(GLuint src)
	{
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_EXTERNAL_OES, src);

		glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
		glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, 0);

        m_program.bind();
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	}
#endif
    
    //////////////////////////////////////////////////////
    
    bool TextureDrawerYUV::init()
    {
        if(!TextureDrawer::init())
            return false;
        
        m_program.bind();
        m_program.sendUniformi("luminanceTexture", 0);
        m_program.sendUniformi("chrominanceTexture", 1);
        return true;
    }
    
    void TextureDrawerYUV::drawTextures(GLuint lumaTex, GLuint chromaTex)
    {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, lumaTex);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, chromaTex);
        drawTextures();
    }
    
    void TextureDrawerYUV::drawTextures()
    {
        m_program.bind();
        glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, 0);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    }
    
    CGEConstString TextureDrawerYUV::getFragmentShaderString()
    {
        return s_fshYUVConvert;
    }
    
    CGEConstString TextureDrawerYUV::getVertexShaderString()
    {
        return s_vsh;
    }
    
    
    //////////////////////////////////////
    
    CGELerpBlurUtil::CGELerpBlurUtil()
    {
        memset(m_texCache, 0, sizeof(MAX_LERP_BLUR_INTENSITY));
        m_intensity = 0;
        m_vertBuffer = 0;
    }
    
    CGELerpBlurUtil::~CGELerpBlurUtil()
    {
        _clearMipmaps();
        if(m_vertBuffer != 0)
            glDeleteBuffers(1, &m_vertBuffer);
    }
    
    bool CGELerpBlurUtil::init()
    {
        memset(m_texCache, 0, sizeof(MAX_LERP_BLUR_INTENSITY));
        m_intensity = MAX_LERP_BLUR_INTENSITY;
        m_program.bindAttribLocation(CGEImageFilterInterface::paramPositionIndexName, 0);
        if(m_program.initWithShaderStrings(g_vshDefaultWithoutTexCoord, g_fshDefault))
        {
            m_isBaseChanged = true;
            
            m_vertBuffer = cgeGenCommonQuadArrayBuffer();
            return true;
        }
        return false;
    }
    
    void CGELerpBlurUtil::setBlurLevel(int value)
    {
        m_intensity = value;
        if(m_intensity > MAX_LERP_BLUR_INTENSITY)
            m_intensity = MAX_LERP_BLUR_INTENSITY;
    }
    
    void CGELerpBlurUtil::_genMipmaps(int width, int height)
    {
        _clearMipmaps();
        GLuint texIDs[MAX_LERP_BLUR_INTENSITY];
        glGenTextures(MAX_LERP_BLUR_INTENSITY, texIDs);
        
        for(int i = 0; i != MAX_LERP_BLUR_INTENSITY; ++i)
        {
            CGESizei sz(_calcLevel(width, i), _calcLevel(height, i));
            if(sz.width < 1)
                sz.width = 1;
            if(sz.height < 1)
                sz.height = 1;
            glBindTexture(GL_TEXTURE_2D, texIDs[i]);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, sz.width, sz.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            m_texCache[i].texID = texIDs[i];
            m_texCache[i].size = sz;
        }
    }
    
    void CGELerpBlurUtil::calcWithTexture(GLuint texture, int width, int height, GLuint target, int targetWidth, int targetHeight)
    {
        m_program.bind();
        glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
        glActiveTexture(GL_TEXTURE0);
        
        glDisable(GL_BLEND);
        
        if(m_texCache[0].texID == 0 || m_cacheTargetWidth != width || m_cacheTargetHeight != height || m_isBaseChanged)
        {
            m_cacheTargetWidth = width;
            m_cacheTargetHeight = height;
            if(m_texCache[0].texID == 0)
                _genMipmaps(width, height);
            m_isBaseChanged = false;
        }
        
        m_framebuffer.bindTexture2D(m_texCache[0].texID);
        glBindTexture(GL_TEXTURE_2D, texture);
        glViewport(0, 0, m_texCache[0].size.width, m_texCache[0].size.height);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        glFlush();
        
        //down scale
        for(int i = 1; i < m_intensity; ++i)
        {
            TextureCache& texCache = m_texCache[i];
            m_framebuffer.bindTexture2D(texCache.texID);
            glViewport(0, 0, texCache.size.width, texCache.size.height);
            
            glBindTexture(GL_TEXTURE_2D, m_texCache[i - 1].texID);
            glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
            glFlush();
        }
        
        //up scale
        for(int i = m_intensity - 1; i > 0; --i)
        {
            TextureCache& texCache = m_texCache[i - 1];
            m_framebuffer.bindTexture2D(texCache.texID);
            glViewport(0, 0, texCache.size.width, texCache.size.height);
            
            glBindTexture(GL_TEXTURE_2D, m_texCache[i].texID);
            glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
            glFlush();
        }
        
        if(target != 0)
        {
            m_framebuffer.bindTexture2D(target);
            glViewport(0, 0, targetWidth, targetHeight);
            glBindTexture(GL_TEXTURE_2D, m_texCache[0].texID);
            glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        }
    }
    
    void CGELerpBlurUtil::drawTexture(GLuint texID)
    {
        m_program.bind();
        glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texID);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    }
    
    void CGELerpBlurUtil::_clearMipmaps()
    {
        if(m_texCache[0].texID != 0)
        {
            GLuint texIDs[MAX_LERP_BLUR_INTENSITY];
            for(int i = 0; i != MAX_LERP_BLUR_INTENSITY; ++i)
                texIDs[i] = m_texCache[i].texID;
            glDeleteTextures(MAX_LERP_BLUR_INTENSITY, texIDs);
            memset(m_texCache, 0, sizeof(MAX_LERP_BLUR_INTENSITY));
            m_cacheTargetWidth = 0;
            m_cacheTargetHeight = 0;
        }
    }
    
    int CGELerpBlurUtil::_calcLevel(int len, int level)
    {
        static float sLevelList[] = {
            2, 3, 5, 7, 10, 14, 19, 26, 35
        };
        int ret = len / sLevelList[level];
        return ret;
//        return roundf(len / (level * 4.0));
    }

}










