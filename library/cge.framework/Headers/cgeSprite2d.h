/*
* cgeSprite2d.h
*
*  Created on: 2014-9-9
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#if !defined(_CGESPRITE2D_H_) && !defined(_CGE_ONLY_FILTERS_)
#define _CGESPRITE2D_H_

#include "cgeSpriteCommon.h"

#define CGE_SPECIAL_SPRITE_CREATE_FUNC(cls, funcName)\
static inline cls* create(int width, int height) \
{\
cls* instance = new cls(width, height); \
if(!instance->funcName()) \
{ \
delete instance; \
instance = nullptr; \
CGE_LOG_ERROR("create %s failed!", #cls); \
} \
return instance; \
}

namespace CGE
{

	class GeometryLineStrip2d;
	class SharedPoint;

	class SpriteInterface2d : public SpriteCommonSettings
	{
	public:
		SpriteInterface2d();

		inline const CGE::Vec2f& getPosition() const { return m_pos; }
		inline const CGE::Vec2f& getScaling() const { return m_scaling; }
		inline const CGE::Vec2f& getHotspot() const { return m_hotspot; }
		inline float getRotation() const { return m_rotation; }
		inline float getAlpha() const { return m_alpha; }
		inline float getZ() const { return m_zIndex; }

		//(0, 0) 表示中心, (-1, -1)表示左上角, (1, 1) 表示右下角
		virtual void setHotspot(float sx, float sy)
		{
			m_hotspot[0] = sx;
			m_hotspot[1] = sy;
		}

		virtual void setHotspot2Center()
		{
			m_hotspot[0] = 0;
			m_hotspot[1] = 0;
		}

		virtual void move(float dx, float dy)
		{
			m_pos[0] += dx;
			m_pos[1] += dy;
		}

		virtual void moveTo(float x, float y)
		{
			m_pos[0] = x;
			m_pos[1] = y;
		}

		virtual void scale(float dsx, float dsy)
		{
			m_scaling[0] *= dsx;
			m_scaling[1] *= dsy;
		}

		virtual void scaleTo(float sx, float sy)
		{
			m_scaling[0] = sx;
			m_scaling[1] = sy;
		}

		virtual void rotate(float dRot)
		{
			m_rotation += dRot;
		}

		virtual void rotateTo(float rot)
		{
			m_rotation = rot;
		}

		virtual void setAlpha(float alpha)
		{
			m_alpha = alpha;
		}

		virtual void setZ(float z)
		{
			m_zIndex = z;
		}

		virtual void render() {	}

		inline bool operator<(const SpriteInterface2d& other) const
		{
			return m_zIndex < other.m_zIndex;
		}

		static bool compZ(const SpriteInterface2d& left, const SpriteInterface2d& right)
		{
			return left.m_zIndex < right.m_zIndex;
		}

		static bool compZp(const SpriteInterface2d* left, const SpriteInterface2d* right)
		{
			return left->m_zIndex < right->m_zIndex;
		}

	protected:
		static CGEConstString paramAttribPositionName;
		static CGEConstString paramProjectionMatrixName;
		static CGEConstString paramHalfTexSizeName;
		static CGEConstString paramRotationName;
		static CGEConstString paramScalingName;
		static CGEConstString paramTranslationName;
		static CGEConstString paramHotspotName;
		static CGEConstString paramAlphaName;
		static CGEConstString paramZIndexName;
		static CGEConstString paramTextureName;
		static CGEConstString paramFilpCanvasName;
		static CGEConstString paramFlipSpriteName;
		static CGEConstString paramBlendColorName;

	protected:
		CGE::Vec2f m_pos; //Sprite2d 的位置
		CGE::Vec2f m_scaling; //Sprite2d 的缩放
		CGE::Vec2f m_hotspot; //Sprite2d 的重心位置(乘以sprite本身尺寸的相对位置)
		float m_rotation; //Sprite2d 的旋转
		float m_alpha; //Sprite2d 的透明度
		float m_zIndex; //Sprite2d 的z值(仅作读取参考，不作为排序依据)
	};

	//使用虚继承， 以使得时间轴可扩展
	class Sprite2d : public virtual SpriteInterface2d
	{
    private:
        Sprite2d(); //兼容性接口， 不应该被调用
	protected:
		Sprite2d(const SharedTexture& texture);
	public:
		virtual CGEConstString getVertexString();
		virtual CGEConstString getFragmentString();
        
        CGE_COMMON_CREATE_FUNC_WITH_PARAM2(Sprite2d, _initProgram, const SharedTexture&);

		virtual ~Sprite2d();

		SharedTexture& getTexture() { return m_texture; }
		void setTexture(const SharedTexture& tex);

        inline void setProjection(float* proj)
        {
            m_program.bind();
            glUniformMatrix4fv(m_projectionLocation, 1, false, proj);
        }
        
		virtual void setCanvasSize(int width, int height)
		{
			Mat4 m = Mat4::makeOrtho(0.0f, (float)width, 0.0f, (float)height, -1e6f, 1e6f);
            setProjection(m[0]);
		}

		virtual void restoreCanvasSize()
		{
			m_program.bind();
			glUniformMatrix4fv(m_projectionLocation, 1, false, sOrthoProjectionMatrix[0]);
		}

		//笛卡尔坐标系与屏幕坐标系的Y轴方向相反，所以默认上下翻转。
		//如果要把sprite绘制到纹理中，可设置不翻转。
		virtual void setCanvasFlip(bool flipX, bool flipY)
		{
			float fx = flipX ? -1.0f : 1.0f;
			float fy = flipY ? -1.0f : 1.0f;
			m_program.bind();
			glUniform2f(m_canvasFlipLocation, fx, fy);
		}

		void restoreCanvasFlip()
		{
			float fx = sCanvasFlipX ? -1.0f : 1.0f;
			float fy = sCanvasFlipY ? -1.0f : 1.0f;
			m_program.bind();
			glUniform2f(m_canvasFlipLocation, fx, fy);
		}

		//默认上下翻转，在直接绘制到canvas上时以正常方向显示图像。
		virtual void setSpriteFlip(bool flipX, bool flipY)
		{
			float fx = flipX ? -1.0f : 1.0f;
			float fy = flipY ? -1.0f : 1.0f;
			m_program.bind();
			glUniform2f(m_spriteFilpLocation, fx, fy);
		}

		void restoreSpriteFlip()
		{
			float fx = sSpriteFlipX ? -1.0f : 1.0f;
			float fy = sSpriteFlipY ? -1.0f : 1.0f;
			m_program.bind();
			glUniform2f(m_spriteFilpLocation, fx, fy);
		}

		virtual void setZ(float z)  //z值范围: -1e20 ~ 1e20 (精度取决于float)
		{
			m_zIndex = z;
			m_program.bind();
			glUniform1f(m_zIndexLocation, z);
		}

		virtual void setAlpha(float alpha)
		{
			m_alpha = alpha;
			m_program.bind();
			glUniform1f(m_alphaLocation, alpha);
		}

		virtual void setHotspot(float sx, float sy)
		{
			m_hotspot[0] = sx;
			m_hotspot[1] = sy;
			m_program.bind();
			glUniform2f(m_hotspotLocation, sx, sy);
		}

		virtual void setHotspot2Center()
		{
			m_hotspot[0] = 0.0f;
			m_hotspot[1] = 0.0f;
			m_program.bind();
			glUniform2f(m_hotspotLocation, 0.0f, 0.0f);
		}

		virtual void move(float dx, float dy)
		{
			m_pos[0] += dx;
			m_pos[1] += dy;
		}

		virtual void moveTo(float x, float y)
		{
			m_pos[0] = x;
			m_pos[1] = y;
		}

		virtual void scale(float dsx, float dsy)
		{
			m_scaling[0] *= dsx;
			m_scaling[1] *= dsy;
		}

		virtual void scaleTo(float sx, float sy)
		{
			m_scaling[0] = sx;
			m_scaling[1] = sy;
		}

		virtual void rotate(float dRot)
		{
			m_rotation += dRot;			
		}

		virtual void rotateTo(float rot)
		{
			m_rotation = rot;
		}

		virtual void render();

	protected:
		bool _initProgram();
		void _clearProgram();

	protected:
		//抽离绘制方式，使子类对绘制有更灵活控制。
		virtual void _drawFunc();
		virtual void _initProgramVars();

		GLint m_posAttribLocation;
		GLint m_projectionLocation;
		GLint m_halfTexLocation;
		GLint m_rotationLocation;
		GLint m_scalingLocation;
		GLint m_translationLocation;
		GLint m_hotspotLocation;
		GLint m_alphaLocation;
		GLint m_zIndexLocation;
		GLint m_textureLocation;
		GLint m_canvasFlipLocation;
		GLint m_spriteFilpLocation;

		ProgramObject m_program;
		SharedTexture m_texture;
	};

	class Sprite2dWithAlphaGradient : public Sprite2d
	{
    protected:
        Sprite2dWithAlphaGradient(const SharedTexture& texture);
	public:
		CGEConstString getVertexString();
		CGEConstString getFragmentString();
		~Sprite2dWithAlphaGradient();
        
        CGE_COMMON_CREATE_FUNC_WITH_PARAM2(Sprite2dWithAlphaGradient, _initProgram, const SharedTexture&);

		void setAlphaTexture(const SharedTexture& tex) { m_texAlpha = tex; }

		void setAlphaFactor(float start, float end);

	protected:
		bool _initProgram();
		void _clearProgram();

	protected:
		virtual void _drawFunc();

		static CGEConstString paramAlphaFactorName;
		static CGEConstString paramTexAlphaName;
		
		GLint m_texAlphaLocation, m_alphaFactorLocation;

		SharedTexture m_texAlpha;
	};

	//////////////////////////////////////////////////////////////////////////

	class Sprite2dInterChange : public Sprite2d
	{
	protected:
        Sprite2dInterChange(const SharedTexture& texture);

	public:
		CGEConstString getVertexString();
		CGEConstString getFragmentString();
		~Sprite2dInterChange();
        
        CGE_COMMON_CREATE_FUNC_WITH_PARAM2(Sprite2dInterChange, _initProgram, const SharedTexture&);

		//viewArea 取值范围 [0, 1]
		inline void setViewArea(const Vec4f& viewArea)
		{
			m_program.bind();
			glUniform4f(m_viewAreaLocation, viewArea[0], viewArea[1], viewArea[2], viewArea[3]);
		}

	protected:
		bool _initProgram();
		void _clearProgram();

	protected:
		static CGEConstString paramViewAreaName;
		GLuint m_viewAreaLocation;
	};

	//提供类似于gif图片显示的效果.  需要提供一张合并了多张小图的“大”纹理
	//然后指定每一帧所在的纹理区域， 之后根据所设置的区域， 以及更新时间间隔进行更新。
	class Sprite2dInterChangeExt : public Sprite2dInterChange
	{
    protected:
        Sprite2dInterChangeExt(const SharedTexture& texture) : Sprite2dInterChange(texture), m_frameIndex(0), m_deltaTime(100.0f), m_deltaAccum(0.0f), m_lastTime(0.0f), m_blendMode(CGEGLOBAL_BLEND_NONE), m_shouldLoop(true) {}
	public:
		~Sprite2dInterChangeExt() {}

        CGE_COMMON_CREATE_FUNC_WITH_PARAM2(Sprite2dInterChangeExt, _initProgram, const SharedTexture&);
        
		void firstFrame();
		void nextFrame(unsigned int offset = 1);

		void updateFrame(double dt); //根据两帧之间的间隔时间更新

		void setFrameTime(double t) { m_lastTime = t; } //设置开始的总时间， 一般为当前时间
		void updateByTime(double t); //根据总时间更新

		void setFPS(float fps) { m_deltaTime = 1000.0f / fps; } //设置sprite切换的帧率， 默认10 fps

		//viewArea 单个分量取值范围 [0, 1]
		void pushViewArea(const Vec4f& area) { m_vecFrames.push_back(area); }
		void flushViewArea();
		void enableLoop(bool loop) { m_shouldLoop = loop; }

		void setBlendMode(CGEGlobalBlendMode blendMode) { m_blendMode = blendMode; }

        inline bool isLastFrame() { return m_frameIndex >= m_vecFrames.size() - 1; }
        inline void setToLastFrame() { m_frameIndex = (unsigned int)m_vecFrames.size() - 1; }
        
	protected:
		void _drawFunc();

		std::vector<Vec4f> m_vecFrames;
		unsigned int m_frameIndex;
		double m_deltaTime, m_deltaAccum, m_lastTime;
		CGEGlobalBlendMode m_blendMode;
		bool m_shouldLoop;
	};
    
    class Sprite2dInterChangeMultiple : public Sprite2dInterChange
    {
    protected:
        Sprite2dInterChangeMultiple(const SharedTexture& tex) : Sprite2dInterChange(tex) {}
        Sprite2dInterChangeMultiple(int width, int height) : Sprite2dInterChange(SharedTexture(width, height)) {}
    public:
        ~Sprite2dInterChangeMultiple();
        
        CGE_SPECIAL_SPRITE_CREATE_FUNC(Sprite2dInterChangeMultiple, _initProgram);
        
        typedef struct SpriteFrame
        {
            Vec4f frame;
            GLuint texture; //此处为纹理id引用， 不可直接delete.
        }SpriteFrame;
        
        typedef struct FrameTexture
        {
            GLuint textureID;
            int width, height; //纹理实际宽高
            int col, row; //纹理包含元素的列与行.
            int count; //纹理包含的总元素个数, 满足条件 count <= col * row.
        }FrameTexture;
        
        void nextFrame(unsigned int offset = 1);
        
        void updateFrame(double dt); //根据时间间隔更新
        
        void setCurrentTime(double t) { m_lastTime = t; }
        
        void updateByTime(double t); //根据总时间更新
        
        void setFrameDelayTime(double dt) { m_deltaTime = dt; }
        
        void setFrameTime(double t) { m_lastTime = t; } //设置开始的总时间， 一般为当前时间
        
        inline void firstFrame() { jumpToFrame(0); }
        
        void jumpToFrame(int frameIndex);
        void jumpToLastFrame();
        inline bool isFirstFrame() { return m_frameIndex == 0; }
        inline bool isLastFrame() { return m_frameIndex == m_vecFrames.size() - 1; }
        
        //必须保证索引一致.
        void setFrameTextures(const std::vector<FrameTexture>& vec);
        void setFrameTextures(FrameTexture* frames, int count);
        
        void enableLoop(bool loop) { m_shouldLoop = loop; }
        
		inline size_t currentFrame() { return m_frameIndex; }
		inline size_t totalFrames() { return m_vecFrames.size(); }

    protected:
        void _clearTextures();
        
        void _setToFrame(const SpriteFrame& frame);
        
//        void _drawFunc();
        void _calcFrames();
        
        std::vector<FrameTexture> m_vecTextures;
        
        std::vector<SpriteFrame> m_vecFrames;
        GLuint m_frameIndex;
        double m_deltaTime, m_deltaAccum, m_lastTime;
        bool m_shouldLoop;
    };

    //////////////////////////////////////////////////////////////////////////
    
    class Sprite2dSequence : public Sprite2d
    {
    protected:
        Sprite2dSequence(int width, int height) : Sprite2d(SharedTexture(width, height)), m_frameIndex(0), m_deltaTime(100.0), m_deltaAccum(0.0), m_lastTime(0.0), m_shouldLoop(true), m_canUpdate(true) {}
    public:
        ~Sprite2dSequence();
        
        CGE_SPECIAL_SPRITE_CREATE_FUNC(Sprite2dSequence, _initProgram);
        
        void firstFrame();
        virtual void nextFrame(unsigned int offset = 1);
        
        virtual void updateFrame(double dt); //根据两帧之间的间隔时间更新
        
        void setFrameTime(double t) { m_lastTime = t; } //设置开始的总时间， 一般为当前时间
        void updateByTime(double t); //根据总时间更新
        size_t getFrameCount () {return m_frameTextures.size();}
        
        //useSec 为 true时表示使用秒为单位， 为 false 时使用毫秒， 默认 false
        void setFPS(double fps, bool useSec = false); //设置sprite切换的帧率， 默认10 fps
        double getCurrentTime(){return (double)m_frameIndex * m_deltaTime ;}
        inline void setFrameDuring(double during) { m_deltaTime = during; }
        
        inline void enableLoop(bool loop) { m_shouldLoop = loop; }
        
        virtual bool isLastFrame();
        virtual void setToLastFrame();
        
        inline unsigned int getFrameIndex() { return m_frameIndex; }
        
        inline void addFrameTexture(GLuint texID) { m_frameTextures.push_back(texID); }
        inline void setFrameTextures(const std::vector<GLuint> v) { m_frameTextures = v; }
        inline std::vector<GLuint>& getFrameTextures() { return m_frameTextures; }
        
        inline void setUpdate(bool update) { m_canUpdate = update; }
        inline bool canUpdate() { return m_canUpdate; }
        
    protected:
        void _drawFunc();
        
        unsigned int m_frameIndex;
        std::vector<GLuint> m_frameTextures;
        double m_deltaTime, m_deltaAccum, m_lastTime;
        bool m_shouldLoop, m_canUpdate;
    };
    
}


#endif
