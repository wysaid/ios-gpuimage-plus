//
//  cgeSoulStuffFilter.h
//  cgeStatic
//
//  Created by Yang Wang on 2017/3/27.
//  Mail: admin@wysaid.org
//  Copyright © 2017年 wysaid. All rights reserved.
//

#include "cgeSoulStuffFilter.h"


static CGEConstString s_vsh = CGE_SHADER_STRING
(
 attribute vec2 vPosition;
 varying vec2 textureCoordinate;
 varying vec2 soulStuffCoord;
 varying float soulStuffAlpha;
 uniform vec2 soulStuffPos;
 uniform float scaling;
void main()
{
    gl_Position = vec4(vPosition, 0.0, 1.0);
    vec2 coord = (vPosition + 1.0) / 2.0;
    textureCoordinate = coord;
    soulStuffCoord = (coord - soulStuffPos) * scaling + soulStuffPos;
    soulStuffAlpha = 1.0 - ((1.0 / scaling) - 1.0) / 0.8;
}
);

static CGEConstString s_fsh = CGE_SHADER_STRING_PRECISION_L
(
 varying vec2 textureCoordinate;
 varying vec2 soulStuffCoord;
 varying float soulStuffAlpha;
 uniform sampler2D inputImageTexture;
 
void main()
{
    vec3 color1 = texture2D(inputImageTexture, textureCoordinate).rgb;
    vec3 color2 = texture2D(inputImageTexture, soulStuffCoord).rgb;
    
    gl_FragColor.rgb = mix(color1, color2, soulStuffAlpha);
    gl_FragColor.a = 1.0;
}
);

namespace CGE
{
    CGEConstString CGESoulStuffFilter::paramSoulStuffPos = "soulStuffPos";
    CGEConstString CGESoulStuffFilter::paramSoulStuffScaling = "scaling";
    
    CGESoulStuffFilter::CGESoulStuffFilter() : m_sizeScaling(1.0f), m_dSizeScaling(0.1f), m_dsMost(1.8f), m_pos(360.0f, 640.0f), m_continuouslyTrigger(true)
    {
        
    }
    
    CGESoulStuffFilter::~CGESoulStuffFilter()
    {
        
    }
    
    bool CGESoulStuffFilter::init()
    {
        if(m_program.initWithShaderStrings(s_vsh, s_fsh))
        {
            m_program.bind();
            m_soulStuffPosLoc = m_program.uniformLocation(paramSoulStuffPos);
            m_soulStuffScalingLoc = m_program.uniformLocation(paramSoulStuffScaling);
            glUniform2f(m_soulStuffPosLoc, m_pos[0], m_pos[1]);
            return true;
        }
        
        return false;
    }
    
    void CGESoulStuffFilter::setSoulStuffPos(float x, float y)
    {
        m_pos[0] = x;
        m_pos[1] = y;
    }
    
    void CGESoulStuffFilter::render2Texture(CGEImageHandlerInterface *handler, GLuint srcTexture, GLuint vertexBufferID)
    {
        m_sizeScaling += m_dSizeScaling;
        
        if(m_sizeScaling >= m_dsMost)
        {
            m_sizeScaling = 1.0f;
            
            if(!m_continuouslyTrigger)
                m_dSizeScaling = 0.0f;
        }
        else if(m_sizeScaling == 1.0f)
        {
            handler->swapBufferFBO();
            return;
        }
        
        handler->setAsTarget();
        const auto& sz = handler->getOutputFBOSize();
        
        m_program.bind();
        glUniform2f(m_soulStuffPosLoc, m_pos[0] / sz.width, m_pos[1] / sz.height);
        glUniform1f(m_soulStuffScalingLoc, 1.0f / m_sizeScaling);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, srcTexture);
        
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
        
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    }
    
    void CGESoulStuffFilter::trigger(float ds, float most)
    {
        m_dSizeScaling = ds;
        m_dsMost = most;
    }
    
    
}
