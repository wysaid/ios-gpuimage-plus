/*
* cgeSlideshow.h
*
*  Created on: 2014-9-9
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#if !defined(_CGESLIDESHOW_H_) && !defined(_CGE_ONLY_FILTERS_)
#define _CGESLIDESHOW_H_

#include "cgeAction.h"
#include "cgeAnimation.h"
#include "cgeSprite2d.h"
#include "cgeScene.h"

namespace CGE
{
	typedef AnimationInterfaceAbstract<TimeActionInterfaceAbstract> TimeLineElem;
	typedef TimeLineInterface<TimeLineElem> TimeLine;

	//////////////////////////////////////////////////////////////////////////

	template<class AnimationType, class SpriteType>
	class AnimationLogicSpriteInterface : public AnimationType, public virtual SpriteType
	{
	public:
//		AnimationLogicSpriteInterface() : AnimationType(), SpriteType() {}
		AnimationLogicSpriteInterface(float start, float end) : AnimationType(start, end), SpriteType() {}
		virtual ~AnimationLogicSpriteInterface() {}

		typedef SpriteType SpriteInterfaceType;
		typedef AnimationType AnimationInterfaceType;

		virtual void render()
		{
			for(typename std::vector<TimeLineElem*>::iterator iter = this->m_children2Run.begin(); iter != this->m_children2Run.end(); ++iter)
			{
				(*iter)->_renderWithFather(this);
			}
		}

	protected:

		virtual float _getZ() const 
		{
			return this->getZ();
		}
	};

	typedef AnimationWithChildrenInterface<TimeActionInterfaceAbstract> AnimAncestor;
	typedef AnimationLogicSpriteInterface<AnimAncestor, SpriteInterface2d> AnimLogicSprite2d;
//	typedef AnimationLogicSpriteInterface<AnimAncestor, Sprite2dWith3dSpaceHelper> AnimLogicSprite2dWith3dSpace;
	
}

#include "cgeSlideshowSprite2d.h"
//#include "cgeSlideshowSprite2dWith3dSpace.h"


#endif
