/*
 * cgeAnimationParser.h
 *
 *  Created on: 2016-5-16
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#if !defined(cgeAnimationParser_h) && !defined(_CGE_ONLY_FILTERS_)
#define cgeAnimationParser_h

#import <GLKit/GLKit.h>

namespace CGE
{
    //返回值类型为 TimeLine. 避免头文件混乱， 这里使用 void* 作为返回值
    void* createSlideshowByConfig(id config, float totalTime);
}


#endif /* cgeAnimationParser_h */
