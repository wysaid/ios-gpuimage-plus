//
//  CustomHelper.cpp
//  filterLib
//
//  Created by wysaid on 16/1/11.
//  Copyright © 2016年 wysaid. All rights reserved.
//

#include "CustomHelper.h"
#include "CustomFilter_0.h"
#include "CustomFilter_N.h"

#define CREATE_FILTER(var, Type) \
do{\
var = new Type(); \
if(!var->init()) \
{\
    delete var; \
    var = nullptr; \
}}while(0);

namespace CGE
{
    CGEImageFilterInterface* cgeCreateCustomFilterByType(CustomFilterType type)
    {
        CGEImageFilterInterface* resultFilter = nullptr;
        
        switch (type)
        {
            case CGE_CUSTOM_FILTER_0:
                CREATE_FILTER(resultFilter, CustomFilter_0);
                break;
            case CGE_CUSTOM_FILTER_1:
                CREATE_FILTER(resultFilter, CustomFilter_1);
                break;
            case CGE_CUSTOM_FILTER_2:
                CREATE_FILTER(resultFilter, CustomFilter_2);
                break;
            case CGE_CUSTOM_FILTER_3:
                CREATE_FILTER(resultFilter, CustomFilter_3);
                break;
            case CGE_CUSTOM_FILTER_4:
                CREATE_FILTER(resultFilter, CustomFilter_4);
                break;
            case CGE_CUSTOM_FILTER_5:
                CREATE_FILTER(resultFilter, CustomFilter_5);
                break;
            default:
                return nullptr;
        }
        
        return resultFilter;
    }
    
}
