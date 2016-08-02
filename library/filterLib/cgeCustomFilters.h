//
//  cgeCustomFilters.h
//  filterLib
//
//  Created by wysaid on 16/1/11.
//  Copyright © 2016年 wysaid. All rights reserved.
//

#ifndef cgeCustomFilters_h
#define cgeCustomFilters_h

typedef enum CustomFilterType
{
    CGE_CUSTOM_FILTER_0,
    CGE_CUSTOM_FILTER_1,
    CGE_CUSTOM_FILTER_2,
    CGE_CUSTOM_FILTER_3,
    CGE_CUSTOM_FILTER_4,
    CGE_FILTER_TOTAL_NUMBER
} CustomFilterType;

#ifdef __OBJC__

#import <UIKit/UIKit.h>
#import "cgeSharedGLContext.h"

#ifdef __cplusplus
extern "C"
{
#endif
    
    //intensity: 0 for origin, 1 for normal, below 0 for neg effect, above 1 for enhanced effect.
    //processingContext: nil for global context, otherwise use the context you provided.
    UIImage* cgeFilterUIImage_CustomFilters(UIImage* uiimage, CustomFilterType type, float intensity, CGESharedGLContext* processingContext);

    //args meanings is the same to the above.
    //type "CGEMutipleEffectFilter" will be returned.
    void* cgeCreateCustomFilter(CustomFilterType type, float intensity, CGESharedGLContext* processingContext);
    
    
#ifdef __cplusplus
}
#endif

#endif
#endif
