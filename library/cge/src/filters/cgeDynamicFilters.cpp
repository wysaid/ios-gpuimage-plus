/*
 * cgeDynamicFilters.cpp
 *
 *  Created on: 2015-11-18
 *      Author: Wang Yang
 */

#include "cgeDynamicFilters.h"

#define COMMON_FUNC(type) \
type* proc = new type();\
if(!proc->init())\
{\
	delete proc;\
	proc = NULL;\
}\
return proc;\

namespace CGE
{

	CGEDynamicWaveFilter* createDynamicWaveFilter()
	{
		COMMON_FUNC(CGEDynamicWaveFilter);
	}
    
    CGEMotionFlowFilter* createMotionFlowFilter()
    {
        COMMON_FUNC(CGEMotionFlowFilter);
    }
    
    CGEMotionFlow2Filter* createMotionFlow2Filter()
    {
        COMMON_FUNC(CGEMotionFlow2Filter);
    }
    
    CGESoulStuffFilter* createSoulStuffFilter()
    {
        COMMON_FUNC(CGESoulStuffFilter);
    }
}
