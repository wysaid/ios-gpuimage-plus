/*
* cgeSlideshowSprite2dWith3dSpace.h
*
*  Created on: 2015-1-8
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#ifndef _CGESLIDESHOWSPRITE2DWITH3DSPACE_H_
#define _CGESLIDESHOWSPRITE2DWITH3DSPACE_H_

#include "cgeSlideshow.h"

namespace CGE
{
	template<class FatherType, class InheritedSpriteType>
	class AnimationSpriteInterface2dWith3dSpace : public FatherType, public InheritedSpriteType
	{
	public:
		AnimationSpriteInterface2dWith3dSpace(float start, float end) : FatherType(start, end) {}
		AnimationSpriteInterface2dWith3dSpace(float start, float end, GLuint texID, int w, int h) : FatherType(start, end), InheritedSpriteType(texID, w, h) {}
		AnimationSpriteInterface2dWith3dSpace(float start, float end, const SharedTexture& tex) : FatherType(start, end), InheritedSpriteType(tex) {}

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

			Vec2f pos, scaling;
			Mat3 mRot;
			float z;

			Sprite2dWith3dSpaceHelper* s = dynamic_cast<Sprite2dWith3dSpaceHelper*>(father);

			if(s != nullptr)
			{
				pos = this->m_pos * s->getScaling() + s->getPosition();
				scaling = this->m_scaling * s->getScaling();
				mRot = s->getRotationMatrix() * this->m_rotMatrix;
				z = this->m_zIndex + s->getZ();
			}
			else
			{
				InheritedSpriteType* f = dynamic_cast<InheritedSpriteType*>(father);
				CGEAssert(f != nullptr); // 类型不兼容
				pos = this->m_pos * f->getScaling() + f->getPosition();
				scaling = this->m_scaling * f->getScaling();
				mRot = f->getRotationMatrix() * this->m_rotMatrix;
				z = this->m_zIndex + f->getZ();

			}

			this->m_program.bind();
			glUniform2f(this->m_translationLocation, pos[0], pos[1]);
			glUniform2f(this->m_scalingLocation, scaling[0], scaling[1]);
			glUniformMatrix3fv(this->m_rotationLocation, 1, GL_FALSE, mRot.data[0]);
			glUniform1f(this->m_zIndexLocation, z);
			this->_drawFunc();

			CGE_LOG_CODE(
				if(!this->m_children2Run.empty())
				{
					CGE_LOG_ERROR("A children with children is not supported by now\n");
				}
				)
		}

		virtual float _getZ() const 
		{
			return this->getZ();
		}
	};
	
	template<class Sprite3dType, class SceneInterfaceType>
	class AnimationSceneInterface : public TimeLineElem, public SceneInterfaceType
	{
	public:
		AnimationSceneInterface() : TimeLineElem(), SceneInterfaceType() {}
		AnimationSceneInterface(float start, float end) : TimeLineElem(start, end), SceneInterfaceType() {}

		//AnimationSceneInterface should not be rendered, and it contains no child.
		void render()
		{
			this->updateView();
			Mat4 m = this->m_projectionMatrix * this->m_modelViewMatrix;
			for(typename std::vector<Sprite3dType*>::iterator iter = m_sprites.begin(); iter != m_sprites.end();
				++iter)
			{
				(*iter)->setMVPMatrix(m);
			}
		}

		//AnimationSceneInterface 不会试图去释放任何 sprite， 也不会渲染任何 sprite
		//你的sprite 仍需要添加至 时间轴中!
		void attachElem(Sprite3dType* sprite) { m_sprites.push_back(sprite); }
		void clearElem() { m_sprites.clear(); }

	private:
		std::vector<Sprite3dType*> m_sprites;
	};

	typedef AnimationSpriteInterface2dWith3dSpace<AnimAncestor, Sprite2dWith3dSpace> AnimSprite2dWith3dSpace;

	typedef AnimationSceneInterface<AnimSprite2dWith3dSpace, SceneInterface> AnimSceneController;

	//AnimSceneControllerDescartes 使用笛卡尔坐标系进行漫游。
	typedef AnimationSceneInterface<AnimSprite2dWith3dSpace, SceneInterfaceDescartes> AnimSceneControllerDescartes;

}

#endif