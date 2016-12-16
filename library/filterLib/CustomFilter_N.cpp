//
//  CustomFilter_N.h
//  filterLib
//
//  Created by wangyang on 16/8/2.
//  Copyright © 2016年 wysaid. All rights reserved.
//

#include "CustomFilter_N.h"

using namespace CGE;

static CGEConstString s_fsh1 = CGE_SHADER_STRING_PRECISION_M
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 const vec3 vr = vec3(1.0, 0.835, 0.835);
 const vec3 vg = vec3(0.0, 0.588, 1.0);
 
 void main()
{
    vec4 src = texture2D(inputImageTexture, textureCoordinate);
    src.rgb = 1.0 - (1.0 - vr * src.r) * (1.0 - vg * src.g);
    gl_FragColor = src;
}
 );

bool CustomFilter_1::init()
{
    return m_program.initWithShaderStrings(g_vshDefaultWithoutTexCoord, s_fsh1);
}

/////////////////////////////////////////////

static CGEConstString s_fsh2 = CGE_SHADER_STRING_PRECISION_H
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 uniform vec2 vSteps;
 const float intensity = 0.45;
 
 float getLum(vec3 src)
{
    return dot(src, vec3(0.299, 0.587, 0.114));
}
 
 void main()
{
    mat3 m;
    vec4 src = texture2D(inputImageTexture, textureCoordinate);
    
    m[0][0] = getLum(texture2D(inputImageTexture, textureCoordinate - vSteps).rgb);
    m[0][1] = getLum(texture2D(inputImageTexture, textureCoordinate - vec2(0.0, vSteps.y)).rgb);
    m[0][2] = getLum(texture2D(inputImageTexture, textureCoordinate + vec2(vSteps.x, -vSteps.y)).rgb);
    m[1][0] = getLum(texture2D(inputImageTexture, textureCoordinate - vec2(vSteps.x, 0.0)).rgb);
    m[1][1] = getLum(src.rgb);
    m[1][2] = getLum(texture2D(inputImageTexture, textureCoordinate + vec2(vSteps.x, 0.0)).rgb);
    m[2][0] = getLum(texture2D(inputImageTexture, textureCoordinate + vec2(-vSteps.x, vSteps.y)).rgb);
    m[2][1] = getLum(texture2D(inputImageTexture, textureCoordinate + vec2(0.0, vSteps.y)).rgb);
    m[2][2] = getLum(texture2D(inputImageTexture, textureCoordinate + vSteps).rgb);
    
    float nx = m[0][0] + m[0][1] + m[0][2] - m[2][0] - m[2][1] - m[2][2];
    float ny = m[0][0] + m[1][0] + m[2][0] - m[0][2] - m[1][2] - m[2][2];
    float ndl = abs(nx + ny + intensity);
    float shade = 0.0;
    
    float norm = (nx * nx + ny * ny + intensity * intensity);
    shade = (ndl * 0.577) / sqrt(norm);
    
    gl_FragColor = vec4(src.rgb * shade, src.a);
}
 );

bool CustomFilter_2::init()
{
    if(m_program.initWithShaderStrings(g_vshDefaultWithoutTexCoord, s_fsh2))
    {
        m_program.bind();
        mStepLoc = m_program.uniformLocation("vSteps");
        return true;
    }
    return false;
}

/////////////////////////////////////////////

static CGEConstString s_fsh3 = CGE_SHADER_STRING_PRECISION_M
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 const vec2 vignette = vec2(0.1, 0.8);
 
 const vec3 c1 = vec3(0.992,0.137,0.314);
 const vec3 c2 = vec3(0.204,0.98,0.725);
 const vec2 vignetteCenter = vec2(0.5, 0.5);
 
 void main(void)
{
    vec4 src = texture2D(inputImageTexture, textureCoordinate);
    
    float d = distance(textureCoordinate, vec2(vignetteCenter.x, vignetteCenter.y));
    float percent = clamp((d-vignette.x)/vignette.y, 0.0, 1.0);
    float alpha = 1.0-percent;
    
    src.rgb = src.rgb * alpha;
    
    src.r = 1.0 - (1.0 - src.r*c1.r) * (1.0 - src.g*c2.r);
    src.g = 1.0 - (1.0 - src.r*c1.g) * (1.0 - src.g*c2.g);
    src.b = 1.0 - (1.0 - src.r*c1.b) * (1.0 - src.g*c2.b);
    
    gl_FragColor = src;
}
 );

bool CustomFilter_3::init()
{
    return m_program.initWithShaderStrings(g_vshDefaultWithoutTexCoord, s_fsh3);
}

/////////////////////////////////////////////

static CGEConstString s_fsh4 = CGE_SHADER_STRING_PRECISION_H
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 uniform vec3 colorGradient[5];
 const float ratio = 1.25;
 
 vec3 soft_light_l3s(vec3 a, vec3 b)
{
    vec3 src;
    a = a * 2.0 - 32768.0;
    
    float tmpr = a.r > 0.0 ? sqrt(b.r)  - b.r : b.r - b.r * b.r;
    src.r = a.r * tmpr / 128.0 + b.r * 256.0;
    
    float tmpg = a.g > 0.0 ? sqrt(b.g)  - b.g : b.g - b.g * b.g;
    src.g = a.g * tmpg / 128.0 + b.g * 256.0;
    
    float tmpb = a.b > 0.0 ? sqrt(b.b)  - b.b : b.b - b.b * b.b;
    src.b = a.b * tmpb / 128.0 + b.b * 256.0;
    return src;
}
 
 void main()
{
    vec4 src = texture2D(inputImageTexture, textureCoordinate);
    vec2 tmpCoord = textureCoordinate * 32768.0 * ratio;
    float ps = tmpCoord.x + tmpCoord.y;
    int pi = int(ps / 16384.0);
    float pr = mod(ps, 16384.0) / 16384.0;
    vec3 v1 = colorGradient[pi];
    vec3 v2 = colorGradient[pi + 1];
    vec3 tmp1 = v1 * (1.0 - pr) + v2 * pr;
    vec3 tmp2 = src.rgb * mat3(0.509, 0.4109, 0.07978,
                               0.209, 0.7109, 0.07978,
                               0.209, 0.4109, 0.3798);
    src.rgb = soft_light_l3s(tmp1, tmp2) / 255.0;
    gl_FragColor = src;
}
 );

bool CustomFilter_4::init()
{
    if(m_program.initWithShaderStrings(g_vshDefaultWithoutTexCoord, s_fsh4))
    {
        const GLfloat colorGradientValue[] =
        {
            0.0f, 0.0f, 32768.0f,
            8000.0f, 7000.0f, 24576.0f,
            16000.0f, 14000.0f, 16384.0f,
            24000.0f, 21000.0f, 8192.0f,
            32000.0f, 28000.0f, 0.0f 
        };
        m_program.bind();
        GLint loc = m_program.uniformLocation("colorGradient");
        if(loc < 0)
            return false;
        glUniform3fv(loc, 5, colorGradientValue);
        return true;
    }
    return false;
}

//////////////////////////////////////////////////////

static CGEConstString s_fshLum = CGE_SHADER_STRING_PRECISION_L
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 void main()
 {
     float lum = dot(texture2D(inputImageTexture, textureCoordinate).rgb, vec3(0.299, 0.587, 0.114));
     gl_FragColor = vec4(lum, lum, lum, 1.0);
 }
);

//半径为2， half最大值滤波. 需要跑两遍
static CGEConstString s_vsh5Step2 = CGE_SHADER_STRING
(
 attribute vec2 vPosition;
 varying vec2 texCoords[5];
 uniform vec2 samplerSteps;
 
 void main()
{
    gl_Position = vec4(vPosition, 0.0, 1.0);
    //An opportunism code. Do not use it unless you know what it means.
    vec2 originCoord = (vPosition.xy + 1.0) / 2.0;
    texCoords[0] = originCoord - samplerSteps * 2.0;
    texCoords[1] = originCoord - samplerSteps;
    texCoords[2] = originCoord;
    texCoords[3] = originCoord + samplerSteps;
    texCoords[4] = originCoord + samplerSteps * 2.0;
}
);

static CGEConstString s_fsh5Step2 = CGE_SHADER_STRING_PRECISION_H
(
 varying vec2 texCoords[5];
 uniform sampler2D inputImageTexture;  //此为单色纹理.
 void main()
 {
     float lum = 0.0;
     for(int i = 0; i < 5; ++i)
     {
         lum = max(lum, texture2D(inputImageTexture, texCoords[i]).r);
     }
     gl_FragColor = vec4(lum, lum, lum, 1.0);
 }
);

static CGEConstString s_fsh5 = CGE_SHADER_STRING_PRECISION_H
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 uniform sampler2D step2Texture;
 
 vec3 levelFunc(vec3 src, vec2 colorLevel)
{
    return clamp((src - colorLevel.x) / (colorLevel.y - colorLevel.x), 0.0, 1.0);
}
 
 vec3 gammaFunc(vec3 src, float value) //value: 0~1
{
    return clamp(pow(src, vec3(value)), 0.0, 1.0);
}
 
 float lum(vec3 src)
{
    return dot(src, vec3(0.299, 0.587, 0.114));
}
 
 void main()
 {
     vec3 origin = texture2D(inputImageTexture, textureCoordinate).rgb; //原图
     float originLum = lum(origin); //原图去色.
     
     //1. 木刻(简化版)
     float cutOutLum = floor(originLum * 4.0) / 4.0; //色阶数4
     float colorLevel_1 = min(cutOutLum / 0.6745, 1.0);
     colorLevel_1 = pow(colorLevel_1, (1.0 / 1.28));
     
     //2. 去色 - 最大值 - 反相
     float step2Color = texture2D(step2Texture, textureCoordinate).r;
     //2. 颜色减淡
     float colorDodge_2 = min(originLum / step2Color, 1.0);
     
     //2. 调节色阶
     float colorLevel_2 = clamp((colorDodge_2 - 0.1412) / 0.7843, 0.0, 1.0);
     colorLevel_2 = pow(colorDodge_2, 0.9615);

     float result = colorLevel_1 * colorLevel_2;
     float resultLevel = clamp((result - 0.196) / 0.651, 0.0, 1.0);
     resultLevel = pow(resultLevel, 0.9259);
     
     gl_FragColor = vec4(resultLevel, resultLevel, resultLevel, 1.0);
 }
);

CustomFilter_5::~CustomFilter_5()
{
    CGE_DELETE_GL_OBJS(glDeleteTextures, m_lumTexture, m_step2Texture);
}

bool CustomFilter_5::init()
{
    m_lumProgram.bindAttribLocation(paramPositionIndexName, 0);
    m_step2Program.bindAttribLocation(paramPositionIndexName, 0);
    if(m_lumProgram.initWithShaderStrings(g_vshDefaultWithoutTexCoord, s_fshLum) &&
       m_step2Program.initWithShaderStrings(s_vsh5Step2, s_fsh5Step2) &&
       m_program.initWithShaderStrings(g_vshDefaultWithoutTexCoord, s_fsh5))
    {
        m_step2Program.bind();
        m_stepLoc = m_step2Program.uniformLocation("samplerSteps");
        m_program.bind();
        m_program.sendUniformi("step2Texture", 1);
        return true;
    }
    return false;
}

void CustomFilter_5::render2Texture(CGE::CGEImageHandlerInterface *handler, GLuint srcTexture, GLuint vertexBufferID)
{
    const auto& sz = handler->getOutputFBOSize();
    if(m_texSize != sz || m_lumTexture == 0 || m_step2Texture == 0)
    {
        m_texSize = sz;
        m_lumTexture = cgeGenTextureWithBuffer(nullptr, sz.width, sz.height, GL_RGBA, GL_UNSIGNED_BYTE);
        m_step2Texture = cgeGenTextureWithBuffer(nullptr, sz.width, sz.height, GL_RGBA, GL_UNSIGNED_BYTE);
    }
    
    glActiveTexture(GL_TEXTURE0);
    glViewport(0, 0, sz.width, sz.height);
    
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    //去色
    {
        m_framebuffer.bindTexture2D(m_lumTexture);
        glBindTexture(GL_TEXTURE_2D, srcTexture);
        m_lumProgram.bind();
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        glFlush();
    }
    
    //最大值
    {
        glBindFramebuffer(GL_FRAMEBUFFER, handler->getFrameBufferID());
        m_step2Program.bind();
        glUniform2f(m_stepLoc, 1.0f / sz.width, 0.0f);
        glBindTexture(GL_TEXTURE_2D, handler->getBufferTextureID());
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        glFlush();
        
        m_framebuffer.bindTexture2D(m_step2Texture);
        glUniform2f(m_stepLoc, 0.0f, 1.0f / sz.height);
        glBindTexture(GL_TEXTURE_2D, handler->getTargetTextureID());
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        glFlush();
    }
    
    handler->setAsTarget();
    glBindTexture(GL_TEXTURE_2D, m_lumTexture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, m_step2Texture);
    
    m_program.bind();
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
}







