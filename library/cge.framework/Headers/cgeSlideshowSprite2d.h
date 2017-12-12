/*
* cgeSlideshowSprite2d.h
*
*  Created on: 2015-1-8
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#ifndef _CGESLIDESHOWSPRITE2D_H_
#define _CGESLIDESHOWSPRITE2D_H_

#include "cgeSlideshow.h"

namespace CGE
{

	//InheritedSpriteType 必须是 FatherType::SpriteInterfaceType 的虚子类
	template<class FatherType, class InheritedSpriteType>
	class AnimationSpriteInterface2d : public FatherType, public InheritedSpriteType
	{
    protected:
//        AnimationSpriteInterface2d(float start, float end) : FatherType(start, end) {}
        AnimationSpriteInterface2d(float start, float end, const SharedTexture& tex) : FatherType(start, end), InheritedSpriteType(tex) {}
	public:
        
        static AnimationSpriteInterface2d* create(float start, float end, const SharedTexture& tex)
        {
            AnimationSpriteInterface2d* sprite = new AnimationSpriteInterface2d(start, end, tex);
            if(!sprite->_initProgram())
            {
                delete sprite;
                sprite = nullptr;
            }
            
            return sprite;
        }

		typedef InheritedSpriteType InheritedSpriteInterfaceType;

		virtual void render()
		{
			InheritedSpriteType::render();
			for(typename std::vector<TimeLineElem*>::iterator iter = this->m_children2Run.begin(); iter != this->m_children2Run.end(); ++iter)
			{
				(*iter)->_renderWithFather(this);
			}
		}

	protected:
		virtual void _renderWithFather(TimeLineElem* father)
		{
			if(!this->m_shouldRender)
				return ;

			FatherType* f = dynamic_cast<FatherType*>(father);
			CGEAssert(f != nullptr);
			Vec2f pos = this->m_pos * f->getScaling() + f->getPosition();
			Vec2f scaling = this->m_scaling * f->getScaling();
			float rot = this->m_rotation + f->getRotation();

			this->m_program.bind();
			glUniform2f(this->m_translationLocation, pos[0], pos[1]);
			glUniform2f(this->m_scalingLocation, scaling[0], scaling[1]);
			glUniform1f(this->m_rotationLocation, rot);
			this->_drawFunc();

			CGE_LOG_CODE(
				if(!this->m_children2Run.empty())
				{
					CGE_LOG_ERROR("A children with children is not supported by now\n");
				}
				)
		}
	};

	//////////////////////////////////////////////////////////////////////////

	//避免编译时产生不必要的实体化
	template<class FatherType>
	class AnimationSpriteInterface2d_InterChange : public FatherType
	{
    protected:
//        AnimationSpriteInterface2d_InterChange(float start, float end) : FatherType(start, end) {}
//        AnimationSpriteInterface2d_InterChange(float start, float end, GLuint texID, int w, int h) : FatherType(start, end, texID, w, h) {}
        AnimationSpriteInterface2d_InterChange(float start, float end, const SharedTexture& tex) : FatherType(start, end, tex) {}
	public:

        static AnimationSpriteInterface2d_InterChange* create(float start, float end, const SharedTexture& tex)
        {
            AnimationSpriteInterface2d_InterChange* sprite = new AnimationSpriteInterface2d_InterChange(start, end, tex);
            if(!sprite->_initProgram())
            {
                delete sprite;
                sprite = nullptr;
            }
            
            return sprite;
        }
        
		bool run(float currentTime)
		{
			this->updateByTime(currentTime);
			return FatherType::run(currentTime);
		}

		void animationStart()
		{
			this->setFrameTime(this->m_startTime);
			this->firstFrame();
			return FatherType::animationStart();
		}
	};

	//////////////////////////////////////////////////////////////////////////

	typedef AnimationSpriteInterface2d<AnimLogicSprite2d, Sprite2d> AnimSprite2d;
	typedef AnimationSpriteInterface2d<AnimLogicSprite2d, Sprite2dWithAlphaGradient> AnimSprite2dWithAlphaGradient;
	typedef AnimationSpriteInterface2d_InterChange<AnimationSpriteInterface2d<AnimLogicSprite2d, Sprite2dInterChangeExt>> AnimSprite2dInterChange;
    
    typedef AnimationSpriteInterface2d_InterChange<AnimationSpriteInterface2d<AnimLogicSprite2d, Sprite2dInterChangeMultiple>> AnimSprite2dInterChangeMultiple;
}

#endif
