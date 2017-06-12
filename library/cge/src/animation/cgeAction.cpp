/*
* cgeAction.h
*
*  Created on: 2014-9-9
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#ifndef _CGE_ONLY_FILTERS_

#include "cgeAction.h"

CGE_LOG_CODE
(
 static bool sRemoveMe(std::vector<CGE::TimeActionInterfaceAbstract*>& vec, CGE::TimeActionInterfaceAbstract* action)
{
    for(std::vector<CGE::TimeActionInterfaceAbstract*>::iterator iter = vec.begin(); iter != vec.end(); ++iter)
    {
        if(*iter == action)
        {
            vec.erase(iter);
            return true;
        }
    }
    return false;
}
 
 //保存所有存在的action, 探测内存泄漏或者进行一些全局设置。
 static std::vector<CGE::TimeActionInterfaceAbstract*> s_actionManager;
 )

namespace CGE
{
    CGE_LOG_CODE
    (
     std::vector<TimeActionInterfaceAbstract*>& TimeActionInterfaceAbstract::getDebugManager()
     {
         return s_actionManager;
     }
    )
    
    
	TimeActionInterfaceAbstract::TimeActionInterfaceAbstract() : m_repeatTimes(1), m_startTime(0), m_endTime(0), m_duringTime(0)
    {
        CGE_LOG_CODE
        (
         s_actionManager.push_back(this);
         )
    }
    
    TimeActionInterfaceAbstract::TimeActionInterfaceAbstract(float startTime, float endTime, float repeatTimes) : m_repeatTimes(repeatTimes), m_startTime(startTime), m_endTime(endTime), m_duringTime(endTime - startTime)
    {
        CGE_LOG_CODE
        (
         s_actionManager.push_back(this);
         )
    }
    
    TimeActionInterfaceAbstract::~TimeActionInterfaceAbstract()
	{
        CGE_LOG_CODE
        (
         if(!sRemoveMe(s_actionManager, this))
            CGE_LOG_ERROR("Global remove action failed! Maybe memory leaks!");
         )
	}

}

#endif