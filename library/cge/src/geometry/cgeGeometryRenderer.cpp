/*
 * cgeGeometryRenderer.cpp
 *
 *  Created on: 2015-1-16
 *      Author: Wang Yang
 */

#include "cgeGeometryRenderer.h"

static CGEConstString s_vsh = CGE_SHADER_STRING
(
 attribute vec4 vPosition;
 
 void main()
 {
     gl_Position = vPosition;
 }
);

static CGEConstString s_fsh = CGE_SHADER_STRING_PRECISION_M
(
 uniform vec4 fragColor;
 void main()
 {
     gl_FragColor = fragColor;
 }
);

namespace CGE
{
    CGEConstString GeometryDrawer::paramFragColorName = "fragColor";
    
    GeometryDrawer::~GeometryDrawer()
    {
        glDeleteBuffers(1, &m_vertBuffer);
    }
    
    bool GeometryDrawer::init()
    {
        glGenBuffers(1, &m_vertBuffer);
        if(m_vertBuffer == 0)
            return false;
        
        m_program.bindAttribLocation("vPosition", 0);
        if(m_program.initWithShaderStrings(getVertexShaderString(), getFragmentShaderString()))
        {
            setFragColor(1.0f, 1.0f, 1.0f, 1.0f);
            return true;
        }
        return false;
    }
    
    CGEConstString GeometryDrawer::getFragmentShaderString()
    {
        return s_fsh;
    }
    
    CGEConstString GeometryDrawer::getVertexShaderString()
    {
        return s_vsh;
    }
    
    void GeometryDrawer::setFragColor(float r, float g, float b, float a)
    {
        m_program.sendUniformf(paramFragColorName, r, g, b, a);
    }
    
    void GeometryDrawer::setupBufferData(const void *data, int dataSize, int dataElemSize, int geomCount, GLenum dataType, int dataElemStride, GLenum usage)
    {
        assert(m_vertBuffer != 0); //You should init buffers first
        
        glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
        glBufferData(GL_ARRAY_BUFFER, dataSize, data, usage);
        
        m_dataElemSize = dataSize;
        m_dataElemSize = dataElemSize;
        m_geometryCount = geomCount;
        m_dataElemStride = dataElemStride;
        m_dataType = dataType;
    }
    
    void GeometryDrawer::drawGeometry(GLenum mode, int first, int count)
    {
        glBindBuffer(GL_ARRAY_BUFFER, m_vertBuffer);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, m_dataElemSize, m_dataType, m_dataNormalized, m_dataElemStride, 0);
        m_program.bind();
        glDrawArrays(mode, first, count);
    }
    
    void GeometryDrawer::drawGeometry(const void* data, int dataSize, int dataElemSize, int geomCount, GLenum dataType, int dataElemStride, GLenum mode, int first, int count)
    {
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, dataElemSize, dataType, GL_FALSE, dataElemStride, data);
        m_program.bind();
        glDrawArrays(mode, first, count);
    }
    
}










