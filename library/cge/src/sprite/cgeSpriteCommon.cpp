/*
* cgeSpriteCommon.cpp
*
*  Created on: 2014-9-25
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#ifndef _CGE_ONLY_FILTERS_

#include "cgeSpriteCommon.h"
#include "cgeGlobal.h"
#include "cgeSprite2d.h"
#include "cgeSprite3d.h"

#define INIT_SPRITE_STATIC_SHADERS(SpriteType) do\
{\
    if(SpriteType::spVertexShader == nullptr) \
        SpriteType::spVertexShader = new ShaderObject();\
    if(SpriteType::spFragmentShader == nullptr) \
        SpriteType::spFragmentShader = new ShaderObject();\
\
	if(!(SpriteType::spVertexShader->init(GL_VERTEX_SHADER) && \
	SpriteType::spVertexShader->loadShaderSourceFromString(SpriteType::getVertexString()) && \
	SpriteType::spFragmentShader->init(GL_FRAGMENT_SHADER) && \
	SpriteType::spFragmentShader->loadShaderSourceFromString(SpriteType::getFragmentString()))) \
{\
	CGE_LOG_ERROR("启动 " #SpriteType " 优化失败"); \
	delete SpriteType::spVertexShader; \
	delete SpriteType::spFragmentShader; \
	SpriteType::spVertexShader = SpriteType::spFragmentShader = nullptr; \
} \
}while(0)

//TODO: 此种方案无法处理较大的转角情况，需要另行更改
static CGEConstString s_vshGeometryLineStrip2d = CGE_SHADER_STRING
(
attribute vec2 aPosition; //使用绝对坐标
attribute vec3 aLineData;

varying float vGradient;

uniform vec2 lineWidth;
uniform vec2 lineFlip;

uniform float gradient;

vec2 rotate90(vec2 v)
{
	return vec2(v.y, -v.x);
}

void main()
{
	vGradient = aLineData.z * gradient;
	vec2 position = aPosition + rotate90(normalize(aLineData.xy)) * aLineData.z * lineWidth;
	gl_Position = vec4(position * lineFlip, 0.0, 1.0);
});

static CGEConstString s_fshGeometryLineStrip2d = CGE_SHADER_STRING_PRECISION_M
(
varying float vGradient;
uniform vec4 color;

void main()
{
	float alpha = 1.0 - abs(vGradient);
	alpha = alpha * alpha * (3.0 - 2.0 * alpha);
)
#if CGE_TEXTURE_PREMULTIPLIED
	"gl_FragColor = color * alpha; }";
#else
	"gl_FragColor = vec4(color.rgb, color.a * alpha);}";
#endif


CGE_LOG_CODE
(
 static bool sRemoveMe(std::vector<CGE::SpriteCommonSettings*>& vec, CGE::SpriteCommonSettings* sprite)
{
    for(std::vector<CGE::SpriteCommonSettings*>::iterator iter = vec.begin(); iter != vec.end(); ++iter)
    {
        if(*iter == sprite)
        {
            vec.erase(iter);
            return true;
        }
    }
    return false;
};
    
 //保存所有存在的sprite, 探测内存泄漏或者进行一些全局设置。
 static std::vector<CGE::SpriteCommonSettings*> s_spriteManager;
 )
    
namespace CGE
{
	void cgeSpritesInitBuiltin()
	{
		INIT_SPRITE_STATIC_SHADERS(Sprite2d);
		INIT_SPRITE_STATIC_SHADERS(Sprite2dExt);
	}

	void cgeSpritesCleanupBuiltin()
	{
		CGE_DELETE(Sprite2d::spVertexShader);
		CGE_DELETE(Sprite2d::spFragmentShader);
		CGE_DELETE(Sprite2dExt::spVertexShader);
		CGE_DELETE(Sprite2dExt::spFragmentShader);
		GeometryLineStrip2d::sClearProgram();
		Sprite2dExt::sReleaseClipProgram();
	}

	//////////////////////////////////////////////////////////////////////////

    CGE_LOG_CODE
    (
     std::vector<SpriteCommonSettings*>& SpriteCommonSettings::getDebugManager()
     {
         return s_spriteManager;
     }
     )
    
	SpriteCommonSettings::SpriteCommonSettings()
	{
        CGE_LOG_CODE
        (
         s_spriteManager.push_back(this);
         )
    }
    
    SpriteCommonSettings::~SpriteCommonSettings()
    {
        CGE_LOG_CODE
        (
         if(!sRemoveMe(s_spriteManager, this))
            CGE_LOG_ERROR("Global remove sprite failed! Maybe memory leaks!");
         )
    }
    
	CGESizei SpriteCommonSettings::sCanvasSize = CGESizei(1024, 768);
	bool SpriteCommonSettings::sCanvasFlipX = false;
	bool SpriteCommonSettings::sCanvasFlipY = false;
	bool SpriteCommonSettings::sSpriteFlipX = false;
	bool SpriteCommonSettings::sSpriteFlipY = false;

	void SpriteCommonSettings::sFlipCanvas(bool x, bool y)
	{
		sCanvasFlipX = x;
		sCanvasFlipY = y;
	}

	void SpriteCommonSettings::sFlipSprite(bool x, bool y)
	{
		sSpriteFlipX = x;
		sSpriteFlipY = y;
	}

	Mat4 SpriteCommonSettings::sOrthoProjectionMatrix = Mat4::makeOrtho(0.0f, 1024.0f, 0.0f, 768.0f, -1e3f, 1e3f);

	//////////////////////////////////////////////////////////////////////////

	CGEConstString GeometryLineStrip2d::paramAttribPositionName = "aPosition";
	CGEConstString GeometryLineStrip2d::paramAttribLineDataName = "aLineData";
	CGEConstString GeometryLineStrip2d::paramLineWidthName = "lineWidth";
	CGEConstString GeometryLineStrip2d::paramLineFlipName = "lineFlip";
	CGEConstString GeometryLineStrip2d::paramColorName = "color";
	CGEConstString GeometryLineStrip2d::paramGradientName = "gradient";

	float GeometryLineStrip2d::sFlipX = 1.0f;
	float GeometryLineStrip2d::sFlipY = -1.0f;
	ProgramObject* GeometryLineStrip2d::s_program = nullptr;
	GLuint GeometryLineStrip2d::s_posAttribLocation = 0, GeometryLineStrip2d::s_lineAttribLocation = 1;

	GLint GeometryLineStrip2d::s_lineWidthLocation;
	GLint GeometryLineStrip2d::s_lineFlipLocation;
	GLint GeometryLineStrip2d::s_canvasSizeLocation;
	GLint GeometryLineStrip2d::s_colorLocation;
	GLint GeometryLineStrip2d::s_gradientLocation;

	GeometryLineStrip2d::GeometryLineStrip2d() : m_color(1.0f, 1.0f, 1.0f, 1.0f), m_lineWidth(4.0f), m_gradient(1.0f)
	{
		glGenBuffers(1, &m_posBuffer);
		glGenBuffers(1, &m_lineBuffer);
		m_posBufferLen = m_lineBufferLen = 0;
		//glGenBuffers(1, &m_elementArrayBuffer);
		assert(m_posBuffer != 0 && m_lineBuffer != 0);
		if(s_program == nullptr)
			_initProgram();
	}

	GeometryLineStrip2d::~GeometryLineStrip2d()
	{
		glDeleteBuffers(1, &m_posBuffer);
		glDeleteBuffers(1, &m_lineBuffer);
		//glDeleteBuffers(1, &m_elementArrayBuffer);
	}

	bool GeometryLineStrip2d::_initProgram()
	{
		s_posAttribLocation = 0;
		s_lineAttribLocation = 1;
		s_program = new ProgramObject;
		s_program->bindAttribLocation(paramAttribPositionName, s_posAttribLocation);
		s_program->bindAttribLocation(paramAttribLineDataName, s_lineAttribLocation);

		if(!s_program->initWithShaderStrings(s_vshGeometryLineStrip2d, s_fshGeometryLineStrip2d))
		{
			GeometryLineStrip2d::sClearProgram();
			CGE_LOG_ERROR("GeometryLineStrip2d - init program failed!");
			return false;
		}

		s_program->bind();
		s_lineWidthLocation = s_program->uniformLocation(paramLineWidthName);
		s_lineFlipLocation = s_program->uniformLocation(paramLineFlipName);
		s_colorLocation = s_program->uniformLocation(paramColorName);
		s_gradientLocation = s_program->uniformLocation(paramGradientName);

		s_program->sendUniformf(paramLineFlipName, sFlipX, sFlipY);		
		return true;
	}

	void GeometryLineStrip2d::_setUniforms()
	{

		glUniform2f(s_lineWidthLocation, m_lineWidth / CGEGlobalConfig::viewWidth, m_lineWidth / CGEGlobalConfig::viewHeight);
		glUniform4f(s_colorLocation, m_color[0], m_color[1], m_color[2], m_color[3]);
		glUniform1f(s_gradientLocation, m_gradient);
	}

	void GeometryLineStrip2d::sClearProgram()
	{
		CGE_DELETE(s_program);
	}

	void GeometryLineStrip2d::pushPoints(std::vector<Vec2f> v)
	{
		m_points.insert(m_points.end(), v.begin(), v.end());
	}

	void GeometryLineStrip2d::flush()
	{
		if(m_points.size() < 2) //point数量不足， 无法绘制
			return;

		m_vecLineData.resize(0);
		m_vecLineData.reserve(m_points.size() * 4);
		m_vecPos.resize(0);
		m_vecPos.reserve(m_points.size() * 4);

		for(std::vector<Vec2f>::size_type i = 1; i < m_points.size(); ++i)
		{
			m_vecPos.push_back(m_points[i-1]);
			m_vecPos.push_back(m_points[i-1]);
			m_vecPos.push_back(m_points[i]);
			m_vecPos.push_back(m_points[i]);

			{
				Vec2f v = m_points[i] - m_points[i - 1];
				Vec3f v0(v[0], v[1], -1.0f), v1(v[0], v[1], 1.0f);
				m_vecLineData.push_back(v0);
				m_vecLineData.push_back(v1);
				m_vecLineData.push_back(v0);
				m_vecLineData.push_back(v1);
			}
		}

		{
			m_vecPos.push_back(m_points[m_points.size() - 1]);
			m_vecPos.push_back(m_points[m_points.size() - 1]);
			m_vecPos.push_back(m_points[0]);
			m_vecPos.push_back(m_points[0]);

			Vec2f v = m_points[0] - m_points[m_points.size() - 1];
			Vec3f v0(v[0], v[1], -1.0f), v1(v[0], v[1], 1.0f);

			m_vecLineData.push_back(v0);
			m_vecLineData.push_back(v1);
			m_vecLineData.push_back(v0);
			m_vecLineData.push_back(v1);
		}

		glBindBuffer(GL_ARRAY_BUFFER, m_posBuffer);
		if(m_posBufferLen == m_vecPos.size())
		{
			glBufferSubData(GL_ARRAY_BUFFER, 0, m_vecPos.size() * sizeof(Vec2f), m_vecPos.data());
		}
		else
		{
			glBufferData(GL_ARRAY_BUFFER, m_vecPos.size() * sizeof(Vec2f), m_vecPos.data(), GL_DYNAMIC_DRAW);
			m_posBufferLen = m_vecPos.size();
		}

		glBindBuffer(GL_ARRAY_BUFFER, m_lineBuffer);
		if(m_lineBufferLen == m_vecLineData.size())
		{
			glBufferSubData(GL_ARRAY_BUFFER, 0, m_vecLineData.size() * sizeof(Vec3f), m_vecLineData.data());
		}
		else
		{
			glBufferData(GL_ARRAY_BUFFER, m_vecLineData.size() * sizeof(Vec3f), m_vecLineData.data(), GL_DYNAMIC_DRAW);
			m_lineBufferLen = m_vecLineData.size();
		}
		

	}

	void GeometryLineStrip2d::render()
	{
		if(m_points.size() < 2) //point数量不足， 无法绘制
			return;
		s_program->bind();

		_setUniforms();
		glBindBuffer(GL_ARRAY_BUFFER, m_posBuffer);
		glEnableVertexAttribArray(s_posAttribLocation);
		glVertexAttribPointer(s_posAttribLocation, 2, GL_FLOAT, false, 0, 0);
		glBindBuffer(GL_ARRAY_BUFFER, m_lineBuffer);
		glEnableVertexAttribArray(s_lineAttribLocation);
		glVertexAttribPointer(s_lineAttribLocation, 3, GL_FLOAT, false, 0, 0);

		glDrawArrays(GL_TRIANGLE_STRIP, 0, (GLsizei)m_points.size() * 4);

		cgeCheckGLError("GeometryLineStrip2d::render");
	}

}

#endif