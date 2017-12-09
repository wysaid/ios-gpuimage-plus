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

//#define INIT_SPRITE_STATIC_SHADERS(SpriteType) do\
//{\
//    if(SpriteType::spVertexShader == nullptr) \
//        SpriteType::spVertexShader = new ShaderObject();\
//    if(SpriteType::spFragmentShader == nullptr) \
//        SpriteType::spFragmentShader = new ShaderObject();\
//\
//	if(!(SpriteType::spVertexShader->init(GL_VERTEX_SHADER) && \
//	SpriteType::spVertexShader->loadShaderSourceFromString(SpriteType::getVertexString()) && \
//	SpriteType::spFragmentShader->init(GL_FRAGMENT_SHADER) && \
//	SpriteType::spFragmentShader->loadShaderSourceFromString(SpriteType::getFragmentString()))) \
//{\
//	CGE_LOG_ERROR("启动 " #SpriteType " 优化失败"); \
//	delete SpriteType::spVertexShader; \
//	delete SpriteType::spFragmentShader; \
//	SpriteType::spVertexShader = SpriteType::spFragmentShader = nullptr; \
//} \
//}while(0)

////TODO: 此种方案无法处理较大的转角情况，需要另行更改
//static CGEConstString s_vshGeometryLineStrip2d = CGE_SHADER_STRING
//(
//attribute vec2 aPosition; //使用绝对坐标
//attribute vec3 aLineData;
//
//varying float vGradient;
//
//uniform vec2 lineWidth;
//uniform vec2 lineFlip;
//
//uniform float gradient;
//
//vec2 rotate90(vec2 v)
//{
//	return vec2(v.y, -v.x);
//}
//
//void main()
//{
//	vGradient = aLineData.z * gradient;
//	vec2 position = aPosition + rotate90(normalize(aLineData.xy)) * aLineData.z * lineWidth;
//	gl_Position = vec4(position * lineFlip, 0.0, 1.0);
//});
//
//static CGEConstString s_fshGeometryLineStrip2d = CGE_SHADER_STRING_PRECISION_M
//(
//varying float vGradient;
//uniform vec4 color;
//
//void main()
//{
//	float alpha = 1.0 - abs(vGradient);
//	alpha = alpha * alpha * (3.0 - 2.0 * alpha);
//)
//#if CGE_TEXTURE_PREMULTIPLIED
//	"gl_FragColor = color * alpha; }";
//#else
//	"gl_FragColor = vec4(color.rgb, color.a * alpha);}";
//#endif


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
//	void cgeSpritesCleanupBuiltin()
//	{
//		CGE_DELETE(Sprite2d::spVertexShader);
//		CGE_DELETE(Sprite2d::spFragmentShader);
//		CGE_DELETE(Sprite2dExt::spVertexShader);
//		CGE_DELETE(Sprite2dExt::spFragmentShader);
//		GeometryLineStrip2d::sClearProgram();
//		Sprite2dExt::sReleaseClipProgram();
//	}

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
}

#endif
