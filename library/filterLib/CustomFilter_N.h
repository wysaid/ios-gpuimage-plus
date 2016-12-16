//
//  CustomFilter_N.h
//  filterLib
//
//  Created by wangyang on 16/8/2.
//  Copyright © 2016年 wysaid. All rights reserved.
//

#ifndef CustomFilter_N_h
#define CustomFilter_N_h

#include "CustomFilter_0.h"

class CustomFilter_1 : public CGE::CGEImageFilterInterface
{
public:
    
    bool init();
    
};

class CustomFilter_2 : public CustomFilter_0
{
public:
    
    bool init();
    
};

class CustomFilter_3 : public CGE::CGEImageFilterInterface
{
public:
    
    bool init();
    
};

class CustomFilter_4 : public CGE::CGEImageFilterInterface
{
public:
    
    bool init();
    
};

class CustomFilter_5 : public CGE::CGEImageFilterInterface
{
public:
    
    ~CustomFilter_5();
    
    bool init();
    
    void render2Texture(CGE::CGEImageHandlerInterface* handler, GLuint srcTexture, GLuint vertexBufferID);
    
protected:
    
    GLuint m_lumTexture, m_step2Texture;
    CGE::ProgramObject m_lumProgram, m_step2Program;
    CGE::FrameBuffer m_framebuffer;
    CGE::CGESizei m_texSize;
    GLint m_stepLoc;
};


#endif
