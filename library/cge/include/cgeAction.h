/*
* cgeAction.h
*
*  Created on: 2014-9-9
*  Created By: Wang Yang
*        Mail: admin@wysaid.org
*/

#if !defined(_CGEACTION_H_) && !defined(_CGE_ONLY_FILTERS_)
#define _CGEACTION_H_

#include "cgeMat.h"
#include "cgeGLFunctions.h"
#include "cgeCurveAdjust.h"
#include <cmath>

namespace CGE
{
	// 抽象类做基类, 提供 real 方法。
	class TimeActionInterfaceAbstract
	{
	public:
        TimeActionInterfaceAbstract();
        TimeActionInterfaceAbstract(float startTime, float endTime, float repeatTimes = 1);
		virtual ~TimeActionInterfaceAbstract();

		virtual void setTimeAttrib(float startTime, float endTime, float repeatTimes = 1)
		{
			m_startTime = startTime;
			m_endTime = endTime;
			m_repeatTimes = repeatTimes;
			m_duringTime = m_endTime - m_startTime;
		}

		inline float startTime() { return m_startTime; }
		inline float endTime() { return m_endTime; }
		inline float& repeatTimes() { return m_repeatTimes; }
		inline float duringTime() { return m_duringTime; }


		// 为了方便统一计算， percent 值域范围必须为[0, 1]， 内部计算时请自行转换。
		virtual void act(float percent) {}

		// 为Action开始做准备工作，比如对一些属性进行复位。(非必须)
		// 注： 可使用actionStart设置未开始的flag变量， 当第一次act执行时标记为开始执行。
		virtual void actionStart() {}

		// Action结束之后的扫尾工作，比如将某物体设置运动结束之后的状态。
		virtual void actionStop() {}

		virtual void bind(void* obj) = 0; // 将动作绑定到某个实际的对象。

		virtual void setArgs(void*) {} // 为后面能够使用配置文件方式预留接口。


		CGE_LOG_CODE(
		static std::vector<TimeActionInterfaceAbstract*>& getDebugManager();
		)

	protected:

		// 在一次TimeAttrib中重复的次数, 对某些操作比较有用，如旋转(可选)
		float m_repeatTimes;

		// 注意：这里的时间是相对于某个 SpriteAnimation 自身的时间，而不是整个时间轴的时间！
		float m_startTime; //起始时间
		float m_endTime; //结束时间
		float m_duringTime; //持续时间
	};

	// TimeActionInterface 定义了Time line可能会用到的公共函数，
	// 这些函数在子类中如果需要用到的话则必须实现它！
	// TimeActionInterface 不计算动作是否开始或者结束
	template<class AnimationSpriteType>
	class TimeActionInterface : public TimeActionInterfaceAbstract
	{
	public:
		TimeActionInterface() : TimeActionInterfaceAbstract(), m_bindObj(nullptr) {}
		TimeActionInterface(float startTime, float endTime, float repeatTimes = 1) : TimeActionInterfaceAbstract(startTime, endTime, repeatTimes), m_bindObj(nullptr) {}

		typedef AnimationSpriteType AnimType;

		AnimationSpriteType*& bindedObj() { return m_bindObj; }
		virtual void bind(void* obj) { m_bindObj = reinterpret_cast<AnimationSpriteType*>(obj); } // 将动作绑定到某个实际的对象。
		AnimationSpriteType* m_bindObj;

	};

	class ActionCurveHelper
	{
	public:

		void attachControlPoints(std::vector<CGECurveInterface::CurvePoint>& points)
		{
			CGECurveInterface::genCurve(m_curve, points.data(), points.size());
		}

		void attachControlPoints(CGECurveInterface::CurvePoint* points, size_t size)
		{
			CGECurveInterface::genCurve(m_curve, points, size);
		}

		void attachControlPoints(std::vector<Vec2f>& points)
		{
			int size = (int)points.size();
			std::vector<CGECurveInterface::CurvePoint> controlPoints(size);
			for (int i = 0; i < size; ++i)
			{
				controlPoints[i].x = points[i].x();
				controlPoints[i].y = points[i].y();
			}
			CGECurveInterface::genCurve(m_curve, controlPoints.data(), size);
		}

	protected:
		std::vector<float> m_curve;
	};

	template<class AnimationSpriteType>
	class UniformAlphaAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		UniformAlphaAction() : TimeActionInterface<AnimationSpriteType>() {}
		UniformAlphaAction(float startTime, float endTime, float alphaFrom, float alphaTo, float repeatTimes = 1.0f, bool shouldInit = false) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes), m_shouldInit(shouldInit)
		{
			setAlphaRange(alphaFrom, alphaTo);
		}

		//本方法独有的设置接口。
		void setAlphaRange(float from, float to)
		{
			m_fromAlpha = from;
			m_toAlpha = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floorf(t);


			this->m_bindObj->setAlpha(m_fromAlpha + (t * m_dis));
		}

		void actionStart()
		{
			if(m_shouldInit)
				this->m_bindObj->setAlpha(m_fromAlpha);
		}

		void actionStop()
		{
			this->m_bindObj->setAlpha(m_toAlpha);
		}

	protected:
		float m_fromAlpha, m_toAlpha, m_dis;
		bool m_shouldInit;
	};

	template<class AnimationSpriteType>
	class AlphaSlowDownAction : public UniformAlphaAction<AnimationSpriteType>
	{
	public:
		AlphaSlowDownAction() : UniformAlphaAction<AnimationSpriteType>() {}
		AlphaSlowDownAction(float startTime, float endTime, float alphaFrom, float alphaTo, float repeatTimes = 1.0f) : UniformAlphaAction<AnimationSpriteType>(startTime, endTime, alphaFrom, alphaTo, repeatTimes) {}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t = 1.0f - (t - floorf(t));
			t = 1.0f - t * t;

			this->m_bindObj->setAlpha(this->m_fromAlpha + (t * this->m_dis));
		}

	};

	template<class AnimationSpriteType>
	class CurveAlphaAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		//本方法独有的设置接口。
		void setAlphaRange(float from, float to)
		{
			m_from = from;
			m_to = to;
			m_dis = to - from;
		}

		void attachControlPoints(std::vector<Vec2f>& points)
		{
			int size = (int)points.size();
			std::vector<CGECurveInterface::CurvePoint> controlPoints(size);
			for (int i = 0; i < size; ++i)
			{
				controlPoints[i].x = points[i].x();
				controlPoints[i].y = points[i].y();
			}
			CGECurveInterface::genCurve(m_curve, controlPoints.data(), size);
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			int sum = (int)m_curve.size() - 1;
			int section1 = t * sum, section2 = CGE_MIN(section1, sum);
			float sectionStart = m_curve[section1];
			float sectionEnd = m_curve[section2];
			float p = t * sum - section1;
			float alpha = m_from + (sectionStart + p * (sectionEnd - sectionStart)) * m_dis;

			this->m_bindObj->setAlpha(alpha);
		}

		void actionStart()
		{
			this->m_bindObj->setAlpha(this->m_from);
		}

		void actionStop()
		{
			this->m_bindObj->setAlpha(this->m_to);
		}

	protected:
		float m_from, m_to;
		float m_dis;
		std::vector<float> m_curve;
	};

	template<class AnimationSpriteType>
	class CurveVelocityAlphaAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		//本方法独有的设置接口。
		void setAlphaRange(float from, float to)
		{
			m_from = from;
			m_to = to;
			m_dis = to - from;
		}

		void setStartAndEnd(float start, float end)
		{
			m_start = start;
			m_end = end;
		}

		void setMax(float max)
		{
			m_max = max;
		}

		void setMotion(float fromX, float fromY, float toX, float toY)
		{
			float disX = toX - fromX;
			float disY = toY - fromY;
			m_distance = sqrt(disX*disX + disY*disY);
		}

		void attachControlPoints(std::vector<Vec2f>& points)
		{
			int size = (int)points.size();
			std::vector<CGECurveInterface::CurvePoint> controlPoints(size);
			for (int i = 0; i < size; ++i)
			{
				controlPoints[i].x = points[i].x();
				controlPoints[i].y = points[i].y();
			}
			CGECurveInterface::genCurve(m_curve, controlPoints.data(), size);

			m_max = 0.0;
			for (int i=0; i < m_curve.size()-1; ++i)
			{
				float start = m_curve[i];
				float end = m_curve[i+1];
				if (fabs(start - end) > m_max) m_max = fabs(start - end);
			}
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			int sum = (int)m_curve.size() - 1;
			int section = t * sum;
			float sectionStart = m_curve[section];
			float sectionEnd = m_curve[section+1];
			float p = fabs(sectionEnd - sectionStart) * m_curve.size() * m_distance / this->m_duringTime / this->m_max;
			if (p > 1.0) p = 1.0;
			if (p < 0.0) p = 0.0;
			float alpha = m_from + p * m_dis;

			this->m_bindObj->setAlpha(alpha);
		}

		void actionStart()
		{
			this->m_bindObj->setAlpha(this->m_start);
		}

		void actionStop()
		{
			this->m_bindObj->setAlpha(this->m_end);
		}

	protected:
		float m_from, m_to;
		float m_dis;
		float m_start, m_end;
		float m_distance;
		float m_max;
		std::vector<float> m_curve;
	};

	template<class AnimationSpriteType>
	class UniformMoveAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:

		UniformMoveAction() : TimeActionInterface<AnimationSpriteType>() {}
		UniformMoveAction(float startTime, float endTime, float moveFromX, float moveFromY, float moveToX, float moveToY, float repeatTimes = 1.0f) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes)
		{
			setMotion(moveFromX, moveFromY, moveToX, moveToY);
		}

		//本方法独有的设置接口。
		void setMotion(float fromX, float fromY, float toX, float toY)
		{
			m_fromX = fromX;
			m_fromY = fromY;
			m_toX = toX;
			m_toY = toY;
			m_disX = toX - fromX;
			m_disY = toY - fromY;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			this->m_bindObj->moveTo(m_fromX + m_disX * t, m_fromY + m_disY * t);
		}

		void actionStop()
		{
			this->m_bindObj->moveTo(m_toX, m_toY);
		}

		void actionStart()
		{
			this->m_bindObj->moveTo(m_fromX, m_fromY);
		}

	protected:
		float m_fromX, m_fromY;
		float m_toX, m_toY;
		float m_disX, m_disY;
	};

	template<class AnimationSpriteType>
	class HitMoveAction : public UniformMoveAction<AnimationSpriteType>
	{
	public:
		
		HitMoveAction(float tStart, float tEnd, float fromX, float fromY, float toX, float toY, bool shouldReinit = false, float repeatTimes = 1)
		{
			this->setTimeAttrib(tStart, tEnd, repeatTimes);
			this->setMotion(fromX, fromY, toX, toY);
			this->m_shouldReinit = shouldReinit;
		}

		void actionStart()
		{
			if(this->m_shouldReinit)
				this->m_bindObj->moveTo(this->m_fromX, this->m_fromY);
		}
		
		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floorf(t);

			if(t < 0.3f)
			{
				t /= 0.3f;
				t *= t;
			}
			else if(t < 0.5f)
			{
				t = 1.0f - (t - 0.3f) * 5.0f;
				t = t * t * 0.5f + 0.5f;
			}
			else if(t < 0.7)
			{
				t = (t - 0.5f) * 5.0f;
				t = t * t * 0.5f + 0.5f;
			}
			else if(t < 0.85f)
			{
				t = 1.0f - (t - 0.7f) / 0.15f;
				t = t * t * 0.25f + 0.75f;
			}
			else
			{
				t = (t - 0.85f) / 0.15f;
				t = t * t * 0.25f + 0.75f;
			}

			this->m_bindObj->moveTo(this->m_fromX + this->m_disX * t, this->m_fromY + this->m_disY * t);
		}

	protected:
		bool m_shouldReinit;
	};

	template<class AnimationSpriteType>
	class NatureMoveAction : public UniformMoveAction<AnimationSpriteType>
	{
	public:
		NatureMoveAction() : m_shouldReinit(false) { }

		NatureMoveAction(float tStart, float tEnd, float fromX, float fromY, float toX, float toY, bool shouldReinit = false, float repeatTimes = 1)
		{
			this->setTimeAttrib(tStart, tEnd, repeatTimes);
			this->setMotion(fromX, fromY, toX, toY);
			this->m_shouldReinit = shouldReinit;
		}

		void actionStart()
		{
			if(this->m_shouldReinit)
				this->m_bindObj->moveTo(this->m_fromX, this->m_fromY);
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);
			t = t * t * (3.0f - 2.0f * t);

			this->m_bindObj->moveTo(this->m_fromX + this->m_disX * t, this->m_fromY + this->m_disY * t);
		}

	protected:
		bool m_shouldReinit;
	};

	template<class AnimationSpriteType>
	class MoveSlowDownAction : public UniformMoveAction<AnimationSpriteType>
	{
	public:
		MoveSlowDownAction() : m_shouldReinit(false) { }

		MoveSlowDownAction(float tStart, float tEnd, float fromX, float fromY, float toX, float toY, bool shouldReinit = false, float repeatTimes = 1)
		{
			this->setTimeAttrib(tStart, tEnd, repeatTimes);
			this->setMotion(fromX, fromY, toX, toY);
			this->m_shouldReinit = shouldReinit;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);
			
			const float n = 2.0f;

			if(t < n)
			{
				float t0 = n - t;
				t = t + t0 * t0 * t0 / (3.0f * n * n) - n / 3.0f;
			}
			else
			{
				float t0 = t - 1.0f;
				t = (t0 * t0 * t0 / (3.0f * (1.0f - n) * (1.0f - n)) + (1.0f - n) / 3.0f) + (2.0f / 3.0f) * n;
			}

			this->m_bindObj->moveTo(this->m_fromX + this->m_disX * t, this->m_fromY + this->m_disY * t);
		}

	protected:
		bool m_shouldReinit;
	};


	template<class AnimationSpriteType>
	class CurveMoveAction : public TimeActionInterface<AnimationSpriteType>, public ActionCurveHelper
	{
	public:

		CurveMoveAction() : m_shouldReinit(true) { }

		CurveMoveAction(float tStart, float tEnd, float fromX, float fromY, float toX, float toY, bool shouldReinit = true, float repeatTimes = 1)
		{
			this->setTimeAttrib(tStart, tEnd, repeatTimes);
			this->setMotion(fromX, fromY, toX, toY);
			this->m_shouldReinit = shouldReinit;
		}

		//本方法独有的设置接口。
		void setMotion(float fromX, float fromY, float toX, float toY)
		{
			m_fromX = fromX;
			m_toX = toX;
			m_fromY = fromY;
			m_toY = toY;
			m_disX = toX - fromX;
			m_disY = toY - fromY;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			int sum = (int)m_curve.size() - 1;
			int section1 = t * sum, section2 = CGE_MIN(section1+1, sum);
			float sectionStart = m_curve[section1];
			float sectionEnd = m_curve[section2];
			float p = t * sum - section1;
			float x = m_fromX + (sectionStart + p * (sectionEnd - sectionStart)) * m_disX;
			float y = m_fromY + (sectionStart + p * (sectionEnd - sectionStart)) * m_disY;

			this->m_bindObj->moveTo(x, y);
		}

		void actionStart()
		{
			if(m_shouldReinit)
				this->m_bindObj->moveTo(this->m_fromX, this->m_fromY);
		}

		void actionStop()
		{
			this->m_bindObj->moveTo(this->m_toX, this->m_toY);
		}

	protected:
		float m_fromX, m_toX;
		float m_fromY, m_toY;
		float m_disX, m_disY;
		bool m_shouldReinit;
	};

	template<class AnimationSpriteType>
	class CurveMove3DAction : public TimeActionInterface<AnimationSpriteType>, public ActionCurveHelper
	{
	public:

		CurveMove3DAction() : m_shouldReinit(true) { }

		CurveMove3DAction(float tStart, float tEnd, float fromX, float fromY, float fromZ, float toX, float toY, float toZ, bool shouldReinit = true, float repeatTimes = 1)
		{
			this->setTimeAttrib(tStart, tEnd, repeatTimes);
			this->setMotion(fromX, fromY, fromZ, toX, toY, toZ);
			this->m_shouldReinit = shouldReinit;
		}

		//本方法独有的设置接口。
		void setMotion(float fromX, float fromY, float fromZ, float toX, float toY, float toZ)
		{
			m_fromX = fromX;
			m_toX = toX;
			m_fromY = fromY;
			m_toY = toY;
			m_fromZ = fromZ;
			m_toZ =toZ;
			m_disX = toX - fromX;
			m_disY = toY - fromY;
			m_disZ = toZ - fromZ;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			int sum = (int)m_curve.size() - 1;
			int section1 = t * sum, section2 = CGE_MIN(section1+1, sum);
			float sectionStart = m_curve[section1];
			float sectionEnd = m_curve[section2];
			float p = t * sum - section1;
			float x = m_fromX + (sectionStart + p * (sectionEnd - sectionStart)) * m_disX;
			float y = m_fromY + (sectionStart + p * (sectionEnd - sectionStart)) * m_disY;
			float z = m_fromZ + (sectionStart + p * (sectionEnd - sectionStart)) * m_disZ;

			this->m_bindObj->moveTo(x, y);
			this->m_bindObj->setZ(z);
		}

		void actionStart()
		{
			if(m_shouldReinit)
			{
				this->m_bindObj->moveTo(this->m_fromX, this->m_fromY);
				this->m_bindObj->setZ(this->m_fromZ);
			}
		}

		void actionStop()
		{
			this->m_bindObj->moveTo(this->m_toX, this->m_toY);
			this->m_bindObj->setZ(this->m_toZ);
		}

	protected:
		float m_fromX, m_toX;
		float m_fromY, m_toY;
		float m_fromZ, m_toZ;
		float m_disX, m_disY, m_disZ;
		bool m_shouldReinit;
	};

	template<class AnimationSpriteType>
	class UniformRotateAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:

        UniformRotateAction() : TimeActionInterface<AnimationSpriteType>() {}
        UniformRotateAction(float startTime, float endTime, float rotFrom, float rotTo, float repeatTimes = 1.0f, bool shouldInit = false) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes)
        {
            setRotationRange(rotFrom, rotTo);
        }
        
		//本方法独有的设置接口。
		void setRotationRange(float from, float to)
		{
			m_fromRot = from;
			m_toRot = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);
			this->m_bindObj->rotateTo(m_fromRot + (t * m_dis));
		}

		void actionStop()
		{
			this->m_bindObj->rotateTo(m_toRot);
		}

	protected:
		float m_fromRot, m_toRot, m_dis;
	};

	template<class AnimationSpriteType>
	class UniformRotate3dAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		UniformRotate3dAction<AnimationSpriteType>(){}

		//本方法提供绕任意轴旋转方法， 第五个参数 axis表示一个三维空间中的任意轴。 注: 请保证 "length(axis) != 0" 
		UniformRotate3dAction<AnimationSpriteType>(float startTime, float endTime, float from, float to, const Vec3f& axis, float repeatTimes = 1.0f) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes)
		{
			setRotationRange(from, to, axis);
		}

		//本方法独有的设置接口。
		void setRotationRange(float from, float to, const Vec3f& axis)
		{
			m_fromRot = from;
			m_toRot = to;
			m_dis = to - from;
			m_axis = axis;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);
			this->m_bindObj->rotateTo(m_fromRot + (t * m_dis), m_axis);
		}

		void actionStop()
		{
			this->m_bindObj->rotateTo(m_toRot, m_axis);
		}

	protected:
		float m_fromRot, m_toRot, m_dis;
		Vec3f m_axis;
	};

	template<class AnimationSpriteType>
	class NatureRotateAction : public UniformRotateAction<AnimationSpriteType>
	{
	public:
		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);
			t = t * t * (3.0f - 2.0f * t);
			this->m_bindObj->rotateTo(this->m_fromRot + (t * this->m_dis));
		}
	};

	template<class AnimationSpriteType>
	class RotateSlowDownAction : public UniformRotateAction<AnimationSpriteType>
	{
	public:
		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);
			t = sqrtf(t);
			this->m_bindObj->rotateTo(this->m_fromRot + (t * this->m_dis));
		}
	};

	template<class AnimationSpriteType>
	class CurveRotateAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		//本方法独有的设置接口。
		void setRotationRange(float from, float to)
		{
			m_fromRot = from;
			m_toRot = to;
			m_dis = to - from;
		}

		void attachControlPoints(std::vector<Vec2f>& points)
		{
			int size = (int)points.size();
			std::vector<CGECurveInterface::CurvePoint> controlPoints(size);
			for (int i = 0; i < size; ++i)
			{
				controlPoints[i].x = points[i].x();
				controlPoints[i].y = points[i].y();
			}
			CGECurveInterface::genCurve(m_curve, controlPoints.data(), size);
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			int sum = (int)m_curve.size() - 1;
			int section = t * sum;
			float sectionStart = m_curve[section];
			float sectionEnd = m_curve[section+1];
			float p = t * sum - section;
			float rotation = m_fromRot + (sectionStart + p * (sectionEnd - sectionStart)) * m_dis;

			this->m_bindObj->rotateTo(rotation);
		}

		void actionStop()
		{
			this->m_bindObj->rotateTo(m_toRot);
		}

	protected:
		float m_fromRot, m_toRot, m_dis;
		std::vector<float> m_curve;
	};


	template<class AnimationSpriteType>
	class UniformScaleAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:

		UniformScaleAction() : TimeActionInterface<AnimationSpriteType>() {}
		UniformScaleAction(float startTime, float endTime, float scaleFrom, float scaleTo, float repeatTimes = 1.0f, bool shouldInit = false) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes), m_shouldInit(shouldInit)
		{
			setScalingRange(scaleFrom, scaleTo);
		}

		void setScalingRange(float from, float to)
		{
			m_fromScaling = from;
			m_toScaling = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			float factor = m_fromScaling + (t * m_dis);
			this->m_bindObj->scaleTo(factor, factor);
		}

		void actionStart()
		{
			if(m_shouldInit)
			{
				this->m_bindObj->scaleTo(m_fromScaling, m_fromScaling);
			}
		}

		void actionStop()
		{
			this->m_bindObj->scaleTo(m_toScaling, m_toScaling);
		}

	protected:
		float m_fromScaling, m_toScaling, m_dis;
		bool m_shouldInit;
	};

	template<class AnimationSpriteType>
	class UniformScaleXYAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:

		UniformScaleXYAction() : TimeActionInterface<AnimationSpriteType>() {}
		UniformScaleXYAction(float startTime, float endTime, const Vec2f& scaleFrom, const Vec2f& scaleTo, float repeatTimes = 1.0f, bool shouldInit = false) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes), m_shouldInit(shouldInit)
		{
			setScalingRange(scaleFrom, scaleTo);
		}

		void setScalingRange(const Vec2f& from, const Vec2f& to)
		{
			m_fromScaling = from;
			m_toScaling = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			Vec2f factor = m_fromScaling + (m_dis * t);
			this->m_bindObj->scaleTo(factor[0], factor[1]);
		}

		void actionStart()
		{
			if(m_shouldInit)
			{
				this->m_bindObj->scaleTo(m_fromScaling[0], m_fromScaling[1]);
			}
		}

		void actionStop()
		{
			this->m_bindObj->scaleTo(m_toScaling[0], m_toScaling[1]);
		}

	protected:
		Vec2f m_fromScaling, m_toScaling, m_dis;
		bool m_shouldInit;
	};

	template<class AnimationSpriteType>
	class ScaleSlowdownAction : public UniformScaleAction<AnimationSpriteType>
	{
	public:

		ScaleSlowdownAction() : UniformScaleAction<AnimationSpriteType>() {}
		ScaleSlowdownAction(float startTime, float endTime, float scaleFrom, float scaleTo, float repeatTimes = 1.0f) : UniformScaleAction<AnimationSpriteType>(startTime, endTime, scaleFrom, scaleTo, repeatTimes) {}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t = 1.0f - (t - floor(t));

			t = 1.0f - t * t;

			float factor = this->m_fromScaling + (t * this->m_dis);
			this->m_bindObj->scaleTo(factor, factor);
		}

	};

	template<class AnimationSpriteType>
	class CurveScaleAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		void setScalingRange(float from, float to)
		{
			m_fromScaling = from;
			m_toScaling = to;
			m_dis = to - from;
		}

		void attachControlPoints(std::vector<Vec2f>& points)
		{
			int size = (int)points.size();
			std::vector<CGECurveInterface::CurvePoint> controlPoints(size);
			for (int i = 0; i < size; ++i)
			{
				controlPoints[i].x = points[i].x();
				controlPoints[i].y = points[i].y();
			}
			CGECurveInterface::genCurve(m_curve, controlPoints.data(), size);
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			int sum = (int)m_curve.size() - 1;
			int section = t * sum;
			float sectionStart = m_curve[section];
			float sectionEnd = m_curve[section+1];
			float p = t * sum - section;
			float scaling = m_fromScaling + (sectionStart + p * (sectionEnd - sectionStart)) * m_dis;

			this->m_bindObj->scaleTo(scaling, scaling);
		}

		void actionStart()
		{
			this->m_bindObj->scaleTo(m_fromScaling, m_fromScaling);
		}

		void actionStop()
		{
			this->m_bindObj->scaleTo(m_toScaling, m_toScaling);
		}

	protected:
		float m_fromScaling, m_toScaling, m_dis;
		std::vector<float> m_curve;
	};

	template<class AnimationSpriteType>
	class ScaleShakeAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		void setScalingRange(float from, float to)
		{
			m_fromScaling = from;
			m_toScaling = to;
			m_dis = to - from;
		}

		void setShakeTime(float shakeTime)
		{
			m_shakeTime = shakeTime;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			//            float scaling = this->m_bindObj->getScaling();
			float x = percent * m_shakeTime;
			float factor = m_fromScaling + (cosf(x*2*M_PI-M_PI)+1.0)/2.0 * m_dis;

			this->m_bindObj->scaleTo(factor, factor);
		}

	protected:
		float m_fromScaling, m_toScaling, m_dis;
		float m_shakeTime;
	};

	template<class AnimationSpriteType>
	class DecelerateMoveAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		// Constructor
		DecelerateMoveAction()
		{
			m_factor = 1.0;
		}

		//本方法独有的设置接口。
		void setFactor(float factor)
		{
			m_factor = factor;
		}

		void setMotion(float fromX, float fromY, float toX, float toY)
		{
			m_fromX = fromX;
			m_fromY = fromY;
			m_toX = toX;
			m_toY = toY;
			m_disX = toX - fromX;
			m_disY = toY - fromY;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			float p = t;
			if (m_factor == 1.0f)
			{
				p = (float)(1.0f - (1.0f - t) * (1.0f - t));
			}
			else
			{
				p = (float)(1.0f - pow((1.0f - t), 2 * m_factor));
			}
			this->m_bindObj->moveTo(m_fromX + m_disX * p, m_fromY + m_disY * p);
		}

		void actionStop()
		{
			this->m_bindObj->moveTo(m_toX, m_toY);
		}

	protected:
		float m_fromX, m_fromY;
		float m_toX, m_toY;
		float m_disX, m_disY;
		float m_factor;
	};

	template<class AnimationSpriteType>
	class AccelerateDecelerateMoveAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:

		//本方法独有的设置接口。
		void setMotion(float fromX, float fromY, float toX, float toY)
		{
			m_fromX = fromX;
			m_fromY = fromY;
			m_toX = toX;
			m_toY = toY;
			m_disX = toX - fromX;
			m_disY = toY - fromY;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			float p = (cosf((t + 1) * M_PI) / 2.0f) + 0.5f;
			this->m_bindObj->moveTo(m_fromX + m_disX * p, m_fromY + m_disY * p);
		}

		void actionStop()
		{
			this->m_bindObj->moveTo(m_toX, m_toY);
		}

	protected:
		float m_fromX, m_fromY;
		float m_toX, m_toY;
		float m_disX, m_disY;
		float m_factor;
	};

	template<class AnimationSpriteType>
	class DecelerateRotateAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		DecelerateRotateAction()
		{
			m_factor = 1.0;
		}

		//本方法独有的设置接口。
		void setFactor(float factor)
		{
			m_factor = factor;
		}

		void setRotationRange(float from, float to)
		{
			m_fromRot = from;
			m_toRot = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			float p = t;
			if (m_factor == 1.0f)
			{
				p = (float)(1.0f - (1.0f - t) * (1.0f - t));
			}
			else
			{
				p = (float)(1.0f - pow((1.0f - t), 2 * m_factor));
			}

			this->m_bindObj->rotateTo(m_fromRot + (p * m_dis));
		}

		void actionStop()
		{
			this->m_bindObj->rotateTo(m_toRot);
		}

	protected:
		float m_fromRot, m_toRot, m_dis;
		float m_factor;
	};

	template<class AnimationSpriteType>
	class AnticipateRotateAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		AnticipateRotateAction()
		{
			m_tension = 2.0;
		}

		//本方法独有的设置接口。
		void setTension(float tension)
		{
			m_tension = tension;
		}

		void setRotationRange(float from, float to)
		{
			m_fromRot = from;
			m_toRot = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			float p = t * t * ((m_tension + 1) * t - m_tension);

			this->m_bindObj->rotateTo(m_fromRot + (p * m_dis));
		}

		void actionStop()
		{
			this->m_bindObj->rotateTo(m_toRot);
		}

	protected:
		float m_fromRot, m_toRot, m_dis;
		float m_tension;
	};

	template<class AnimationSpriteType>
	class AccelerateDecelerateRotateAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		//本方法独有的设置接口。
		void setRotationRange(float from, float to)
		{
			m_fromRot = from;
			m_toRot = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			float p = (cosf((t + 1) * M_PI) / 2.0f) + 0.5f;

			this->m_bindObj->rotateTo(m_fromRot + (p * m_dis));
		}

		void actionStop()
		{
			this->m_bindObj->rotateTo(m_toRot);
		}

	protected:
		float m_fromRot, m_toRot, m_dis;
	};

	template<class AnimationSpriteType>
	class CameraSimulationAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		void addSpriteGroup(AnimationSpriteType *logicSprite, AnimationSpriteType *displaySprite, AnimationSpriteType *smoothedSprite = 0, bool translucency = false)
		{
			m_logicSprites.push_back(logicSprite);
			m_displaySprites.push_back(displaySprite);
			m_smoothedSprites.push_back(smoothedSprite);
			m_isTranslucency.push_back(translucency);
		}

		void setComposeSize(float width, float height)
		{
			m_composeSize = Vec2f(width, height);
		}

		void setViewportSize(float width, float height)
		{
			m_viewportSize = Vec2f(width, height);
		}

		void setProjectionMat(Mat4 mat)
		{
			m_projectionMat = mat;
		}

		void setFocus(float focus)
		{
			m_focus = focus;
		}

		void setDepth(float depth)
		{
			m_depth = depth;
		}

		void act(float percent)
		{
			Vec2f posCamera = this->m_bindObj->getPosition();
			float zCamera = this->m_bindObj->getZ();
			float rotationCamera = this->m_bindObj->getRotation();
			Vec2f scalingCamera = this->m_bindObj->getScaling();
			Mat4 cameraModelViewMat = Mat4::makeScale(1.0f/scalingCamera.x(), 1.0f/scalingCamera.y(), 1.0f) * Mat4::makeRotation(rotationCamera, 0.0f, 0.0f, 1.0f) * Mat4::makeTranslation(-posCamera.x(), -posCamera.y(), -zCamera);

			for (int i = 0; i < m_logicSprites.size(); ++i)
			{
				AnimationSpriteType* logicSprite = m_logicSprites[i];
				Vec2f pos = logicSprite->getPosition();
				float z = logicSprite->getZ();
				float rotation = logicSprite->getRotation();
				Vec2f scaling = logicSprite->getScaling();
				Mat4 modelViewMat = cameraModelViewMat * Mat4::makeTranslation(pos.x(), pos.y(), z) * Mat4::makeRotation(rotation, 0.0f, 0.0f, 1.0f) /** Mat4::makeScale(scaling.x(), scaling.y(), 1.0f)*/;
				Mat4 modelViewProjection = m_projectionMat * modelViewMat;

				Vec4f centerPos = modelViewProjection * Vec4f(0.0f, 0.0f, 0.0f, 1.0f);
				Mat4 scalingMat = m_projectionMat * Mat4::makeScale(scaling.x(), scaling.y(), 1.0f) * Mat4::makeTranslation(0.0f, 0.0f, -zCamera+z);
				Vec4f rightPos = scalingMat * Vec4f(1.0f, 0.0f, 0.0f, 1.0f);
				Vec4f topPos = scalingMat * Vec4f(0.0f, 1.0f, 0.0f, 1.0f);
				float minSize = CGE::CGE_MIN(m_composeSize.x(), m_composeSize.y());
				float maxSize = CGE::CGE_MAX(m_composeSize.x(), m_composeSize.y());
				Mat4 viewportMat = Mat4::makeTranslation(maxSize/2.0f, maxSize/2.0f, 0.0f) * Mat4::makeScale(maxSize/2.0f, maxSize/2.0f, 1.0);
				centerPos /= centerPos.w();
				rightPos /= rightPos.w();
				topPos /= topPos.w();
				centerPos = viewportMat * centerPos;
				rightPos = Mat4::makeScale(maxSize/2.0f, maxSize/2.0f, 1.0) * rightPos;
				topPos = Mat4::makeScale(maxSize/2.0f, maxSize/2.0f, 1.0) * topPos;
				{
					centerPos.x() = centerPos.x() - (maxSize - minSize) / 2.0f;
					centerPos.y() = centerPos.y() - (maxSize - minSize) / 2.0f;

					float factor = CGE::CGE_MIN(m_viewportSize.x(), m_viewportSize.y()) / minSize;
					centerPos.x() *= factor;
					centerPos.y() *= factor;
					rightPos.x() *= factor;
					topPos.y() *= factor;
				}

				AnimationSpriteType* displaySprite = m_displaySprites[i];
				AnimationSpriteType* smoothedSprite = m_smoothedSprites[i];
				float deltaZ = zCamera - z;
				if (deltaZ <= 0)
				{
					displaySprite->setAlpha(0.0f);
					if (smoothedSprite) smoothedSprite->setAlpha(0.0f);
				}
				else
				{
					float alpha = logicSprite->getAlpha();
					if (smoothedSprite)
					{
						float disZ = fabs(m_focus - deltaZ);
						float alphaSmoothed = alpha;
						if (disZ < m_depth) alphaSmoothed = alpha * (1.0f - (m_depth - disZ) / m_depth);
						if (m_isTranslucency[i]) alpha -= alphaSmoothed;

						smoothedSprite->setAlpha(alphaSmoothed);
						smoothedSprite->moveTo(centerPos.x(), centerPos.y());
						smoothedSprite->rotateTo(rotationCamera+rotation);
						smoothedSprite->scaleTo(rightPos.x(), topPos.y());
					}
					displaySprite->setAlpha(alpha);
					displaySprite->moveTo(centerPos.x(), centerPos.y());
					displaySprite->rotateTo(rotationCamera+rotation);
					displaySprite->scaleTo(rightPos.x(), topPos.y());
				}
			}
		}

	protected:
		std::vector<AnimationSpriteType*> m_logicSprites;
		std::vector<AnimationSpriteType*> m_displaySprites;
		std::vector<AnimationSpriteType*> m_smoothedSprites;
		std::vector<bool> m_isTranslucency;
		Vec2f m_composeSize;
		Vec2f m_viewportSize;
		Mat4 m_projectionMat;
		float m_focus;
		float m_depth;
	};

	template<class AnimationSpriteType>
	class UniformMoveZAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:

		UniformMoveZAction() : TimeActionInterface<AnimationSpriteType>() {}
		UniformMoveZAction(float startTime, float endTime, float fromZ, float toZ, float repeatTimes = 1.0f) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes)
		{
			setMotion(fromZ, toZ);
		}

		//本方法独有的设置接口。
		void setMotion(float fromZ, float toZ)
		{
			m_fromZ = fromZ;
			m_toZ = toZ;
			m_disZ = toZ - fromZ;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floor(t);

			this->m_bindObj->setZ(m_fromZ + m_disZ * t);
		}

		void actionStop()
		{
			this->m_bindObj->setZ(m_toZ);
		}

	protected:
		float m_fromZ, m_toZ, m_disZ;
	};

	template<class AnimationSpriteType>
	class DynamicSpecialAlphaAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		DynamicSpecialAlphaAction() : TimeActionInterface<AnimationSpriteType>() {}
		DynamicSpecialAlphaAction(float startTime, float endTime, float startFrom, float startTo, float endFrom, float endTo, float repeatTimes = 1.0f) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes)
		{
			setDynamicAlpha(startFrom, startTo, endFrom, endTo);
		}

		//本方法独有的设置接口。
		void setDynamicAlpha(float startFrom, float startTo, float endFrom, float endTo)
		{
			m_startAlphaFrom = startFrom;
			m_startAlphaTo = startTo;
			m_startAlphaDis = startTo - startFrom;
			m_endAlphaFrom = endFrom;
			m_endAlphaTo = endTo;
			m_endAlphaDis = endTo - endFrom;
		}

		void act(float percent)
		{
            float t = this->m_repeatTimes * percent;
            t -= floor(t);
            
            if (this->natureAlpha) {  
                t = t * t * (3.0f - 2.0f * t);
            }
            
            this->m_bindObj->setAlphaFactor(m_startAlphaFrom + (t * m_startAlphaDis), m_endAlphaFrom + (t * m_endAlphaDis));
		}

		void actionStart()
		{
			this->m_bindObj->setAlphaFactor(m_startAlphaFrom, m_endAlphaFrom);
		}

		void actionStop()
		{
			this->m_bindObj->setAlphaFactor(m_startAlphaTo, m_endAlphaTo);
		}
        
        void setNatureAlpha(bool nature){
            this->natureAlpha = nature;
        }

	protected:
		float m_startAlphaFrom, m_startAlphaTo, m_startAlphaDis;
		float m_endAlphaFrom, m_endAlphaTo, m_endAlphaDis;
        
        bool natureAlpha;
	};

	//////////////////////////////////////////////////////////////////////////

	//位置参数包含三个分量， 分别表示当前位置的x, y, z
	//可以设置相机移动到三维世界的任何位置
	template<class AnimationSpriteType>
	class SceneCameraMoveAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		SceneCameraMoveAction() : TimeActionInterface<AnimationSpriteType>() {}
		SceneCameraMoveAction(float startTime, float endTime, const Vec3f& fromPos, const Vec3f& toPos, float repeatTimes = 1.0f, bool shouldInit = false) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes), m_shouldInit(shouldInit)
		{
			setMotion(fromPos, toPos);
		}

		//本方法独有的设置接口。
		void setMotion(const Vec3f& from, const Vec3f& to)
		{
			m_fromPos = from;
			m_toPos = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floorf(t);
            t = t * t * (3.0f - 2.0f * t);
			this->m_bindObj->setEye(m_fromPos + (m_dis * t));
		}

		void actionStart()
		{
			if(m_shouldInit)
			{
				this->m_bindObj->setEye(m_fromPos);
			}
		}

		void actionStop()
		{
			this->m_bindObj->setEye(m_toPos);
		}

	protected:
		Vec3f m_fromPos, m_toPos, m_dis;
		bool m_shouldInit;
	};

	
	//转动视角动作。
	//旋转参数为弧度， 当弧度>0 时， 为向右旋转， 否则为向左旋转。
	template<class AnimationSpriteType>
	class SceneCameraRotateAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		SceneCameraRotateAction() : TimeActionInterface<AnimationSpriteType>() {}
		SceneCameraRotateAction(float startTime, float endTime, float fromRot, float toRot, float repeatTimes = 1.0f, bool shouldInit = false) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes), m_shouldInit(shouldInit)
		{
			setRotation(fromRot, toRot);
		}

		//本方法独有的设置接口。
		void setRotation(float fromRot, float toRot)
		{
			m_fromRot = fromRot;
			m_toRot = toRot;
			m_dis = toRot - fromRot;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floorf(t);

			this->m_bindObj->turnTo(m_fromRot + (m_dis * t));
		}

		void actionStart()
		{
			if(m_shouldInit)
			{
				this->m_bindObj->turnTo(m_fromRot);
			}
		}

		void actionStop()
		{
			this->m_bindObj->turnTo(m_toRot);
		}

	protected:
		float m_fromRot, m_toRot, m_dis;
		bool m_shouldInit;
	};

	template<class AnimationSpriteType>
	class SceneCameraRotateAction2 : public SceneCameraRotateAction<AnimationSpriteType>
	{
	public:
		SceneCameraRotateAction2(float startTime, float endTime, float fromRot, float toRot, float repeatTimes = 1.0f, bool shouldInit = false) : SceneCameraRotateAction<AnimationSpriteType>(startTime, endTime, fromRot, toRot, repeatTimes, shouldInit) {}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floorf(t);
			t = t * t * (3.0f - 2.0f * t);
			this->m_bindObj->turnTo(this->m_fromRot + (this->m_dis * t));
		}
	};

	//向上观察动作。 当弧度大小为正时， 为仰视， 否则为俯视
	//范围参考：[-PI/2.4, PI/2.4], 约正负75度角
	//当超过此范围时， 会进行截断
	template<class AnimationSpriteType>
	class SceneCameraLookupAction : public TimeActionInterface<AnimationSpriteType>
	{
	public:
		SceneCameraLookupAction() : TimeActionInterface<AnimationSpriteType>() {}
		SceneCameraLookupAction(float startTime, float endTime, float from, float to, float repeatTimes = 1.0f, bool shouldInit = false) : TimeActionInterface<AnimationSpriteType>(startTime, endTime, repeatTimes), m_shouldInit(shouldInit)
		{
			setLooking(from, to);
		}

		//本方法独有的设置接口。
		void setLooking(float from, float to)
		{
			m_from = from;
			m_to = to;
			m_dis = to - from;
		}

		void act(float percent)
		{
			float t = this->m_repeatTimes * percent;
			t -= floorf(t);

			this->m_bindObj->lookUpTo(m_from + (m_dis * t));
		}

		void actionStart()
		{
			if(m_shouldInit)
			{
				this->m_bindObj->lookUpTo(m_from);
			}
		}

		void actionStop()
		{
			this->m_bindObj->lookUpTo(m_to);
		}

	protected:
		float m_from, m_to, m_dis;
		bool m_shouldInit;
	};

}


#endif
