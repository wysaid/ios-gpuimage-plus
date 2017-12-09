/*
* cgeSprite3d.h
*
*  Created on: 2014-10-16
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#if! defined(_CGESPRITE3d_H_) && !defined(_CGE_ONLY_FILTERS_)
#define _CGESPRITE3d_H_

#include "cgeSpriteCommon.h"

namespace CGE
{
	//仅提供统一、与SpriteInterface2d一致的接口.
	class SpriteInterface3d : public SpriteCommonSettings
	{
	public:

		SpriteInterface3d();		
		virtual ~SpriteInterface3d() {}

		inline Vec3f& getPosition() { return m_pos; }
		inline Vec3f& getScaling() { return m_scaling; }
		inline Vec3f& getHotspot() { return m_hotspot; }
		inline Mat3& getRotation() { return m_rotation; }
		inline float getAlpha() const { return m_alpha; }
		inline float getZ() const { return m_zIndex; }
		
		virtual void setHotspot(const Vec3f& hotspot)
		{
			m_hotspot = hotspot;
		}

		virtual void setHotspot2Center()
		{
			m_hotspot = 0.0f;
		}

		virtual void move(const Vec3f& pos)
		{
			m_pos += pos;
		}

		virtual void moveX(float x)
		{
			m_pos[0] += x;
		}

		virtual void moveY(float y)
		{
			m_pos[1] += y;
		}

		virtual void moveZ(float z)
		{
			m_pos[2] += z;
		}

		virtual void moveTo(const Vec3f& pos)
		{
			m_pos = pos;
		}

		virtual void scale(const Vec3f& scaling)
		{
			m_scaling *= scaling;
		}

		virtual void scaleX(float sx)
		{
			m_scaling[0] *= sx;
		}

		virtual void scaleY(float sy)
		{
			m_scaling[1] *= sy;
		}

		virtual void scaleZ(float sz)
		{
			m_scaling[2] *= sz;
		}

		virtual void scaleTo(const Vec3f& scaling)
		{
			m_scaling = scaling;
		}

		virtual void rotate(float rad, float x, float y, float z)
		{
			m_rotation.rotate(rad, x, y, z);
		}

		virtual void rotateX(float rx)
		{
			m_rotation.rotateX(rx);
		}

		virtual void rotateY(float ry)
		{
			m_rotation.rotateY(ry);
		}

		virtual void rotateZ(float rz)
		{
			m_rotation.rotateZ(rz);
		}

		virtual void rotateTo(float rad, float x, float y, float z)
		{
			m_rotation = Mat3::makeRotation(rad, x, y, z);
		}

		virtual void rotateToX(float rx)
		{
			m_rotation = Mat3::makeXRotation(rx);
		}

		virtual void rotateToY(float ry)
		{
			m_rotation = Mat3::makeYRotation(ry);
		}

		virtual void rotateToZ(float rz)
		{
			m_rotation = Mat3::makeZRotation(rz);
		}

		virtual void restoreRotation()
		{
			m_rotation.loadIdentity();
		}

		virtual void setAlpha(float alpha)
		{
			m_alpha = alpha;
		}

		virtual void setZ(float z)
		{
			m_zIndex = z;
		}

		virtual void render() {} 

		inline bool operator<(const SpriteInterface3d& other) const
		{
			return m_zIndex < other.m_zIndex;
		}

		static bool compZ(const SpriteInterface3d& left, const SpriteInterface3d& right)
		{
			return left.m_zIndex < right.m_zIndex;
		}

		static bool compZp(const SpriteInterface3d* left, const SpriteInterface3d* right)
		{
			return left->m_zIndex < right->m_zIndex;
		}

	protected:
		static CGEConstString paramAttribPositionName;

	protected:
		Vec3f m_pos; //Sprite3d 的位置
		Vec3f m_scaling; //Sprite3d 的缩放
		Vec3f m_hotspot; //Sprite3d 的重心位置 以模型大小为比例尺， 中心点(默认值)为(0,0,0)
		Mat3 m_rotation; //Sprite3d 的旋转, 分别表示绕重心位置的(yOz), (xOz), (xOy) 平面旋转. 
		float m_alpha; //Sprite3d 的透明度
		float m_zIndex; //Sprite3d 的z值（无实际意义， Sprite3d的坐标包含z值， 这里的zIndex仅作为动画过程中的渲染排序依据		
	};

	//////////////////////////////////////////////////////////////////////////

	class Sprite3d : public virtual SpriteInterface3d
    {
    public:
        Sprite3d() : SpriteInterface3d() {}
        ~Sprite3d();
        
        virtual void renderWithMat(const Mat4& modelView) = 0;
        virtual void setProjectionMatrix(const Mat4& proj) {}
        
    protected:
        virtual bool _initProgram(CGEConstString vsh, CGEConstString fsh);
        virtual void _bindProgramLocations();
        virtual void _initProgramUniforms() {}
        
        inline Mat4 _calcMat() const
        {
            return (Mat4(m_scaling[0], 0.0f, 0.0f, 0.0f,
                         0.0f, m_scaling[1], 0.0f, 0.0f,
                         0.0f, 0.0f, m_scaling[2], 0.0f,
                         m_pos[0], m_pos[1], m_pos[2], 1.0f) * m_rotation);
        }
        
    protected:
        ProgramObject m_program;
    };
    
    ////////////////////////////////////////////////////////////////////////
    
    typedef struct SpriteArrayBufferComponent
    {
        SpriteArrayBufferComponent() : bufferData(nullptr), bufferID(0), componentSize(0), bufferBytes(0), elementCnt(0), bufferKind(GL_FALSE), bufferUsage(GL_FALSE), bufferDataKind(GL_FALSE), bufferStride(0) {}
        SpriteArrayBufferComponent(const void* buffer, GLsizei compSize, GLsizei bytes, GLenum bufKind, GLenum bufUsage, GLenum dataKind, GLsizei elemCnt = 0, GLsizei stride = 0) : bufferData(buffer), bufferID(0), componentSize(compSize), bufferBytes(bytes), elementCnt(elemCnt), bufferKind(bufKind), bufferUsage(bufUsage), bufferDataKind(dataKind), bufferStride(stride) {}
        
        SpriteArrayBufferComponent(GLuint bufID, int compSize, int bytes, GLenum bufKind, GLenum bufUsage, GLenum dataKind, GLsizei elemCnt = 0, GLsizei stride = 0) : bufferData(nullptr), bufferID(0), componentSize(compSize), bufferBytes(bytes), elementCnt(elemCnt), bufferKind(bufKind), bufferUsage(bufUsage), bufferDataKind(dataKind), bufferStride(stride) {}
        
        const void* bufferData;
        GLuint bufferID;
        GLsizei componentSize; // 每个分量的大小(not bytes)
        GLsizei bufferBytes; //buffer 大小
        GLsizei elementCnt;
        GLenum bufferKind, bufferUsage; //bufferKind: GL_ARRAY_BUFFER/GL_ELEMENT_ARRAY_BUFFER, bufferUsage: GL_STATIC_DRAW/GL_DYNAMIC_DRAW/GL_STREAM_DRAW
        GLenum bufferDataKind; //buffer数据类型 GL_FLOAT/GL_UNSIGNED_SHORT
        GLsizei bufferStride; //buffer 步长
    }ArrayBufferComponent;
    
	//仅供演示， 若要更灵活使用， 请继承Sprite3d，并重写shader等部分
	class Sprite3dExt : public Sprite3d
	{
// 	protected:
// 		Sprite3d(bool bInitProgram) : SpriteInterface3d() { CGEAssert(!bInitProgram); }

	public:
		Sprite3dExt() : SpriteInterface3d(), m_mvpLocation(0) {}
		~Sprite3dExt();

		//子类需要重写自己的init方法， 请勿多态使用init函数。
		bool init(const ArrayBufferComponent& vertex, const ArrayBufferComponent& vertexElementArray, GLenum drawFunc);
		
		virtual void renderWithMat(const Mat4& modelViewProjectionMatrix);

	protected:

		inline GLuint genBufferWithComponent(const ArrayBufferComponent& component)
		{
			GLuint bufferID = 0;
			glGenBuffers(1, &bufferID);
			glBindBuffer(component.bufferKind, bufferID);
			glBufferData(component.bufferKind, component.bufferBytes, component.bufferData, component.bufferUsage);
			return bufferID;
        }
        
        void _initProgramUniforms();

	protected:
        GLint m_mvpLocation;
		ProgramObject m_program;
		ArrayBufferComponent m_vertBuffer, m_vertElementBuffer; //仅包含几何形状
		GLenum m_drawFunc;

	};

}

#endif
