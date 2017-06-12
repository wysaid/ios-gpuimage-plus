//
//  cgeCustomFilters.mm
//  filterLib
//
//  Created by wysaid on 16/1/11.
//  Copyright © 2016年 wysaid. All rights reserved.
//

#include "cgeCustomFilters.h"

#include "cgeUtilFunctions.h"
#include "cgeImageHandlerIOS.h"
#include "cgeMultipleEffects.h"
#include "CustomHelper.h"

using namespace CGE;

extern "C"
{
    void* cgeCreateCustomFilter(CustomFilterType type, float intensity, CGESharedGLContext* processingContext)
    {
        if(type < 0 || type >= CGE_FILTER_TOTAL_NUMBER)
            return nullptr;
        
        __block CGEMutipleEffectFilter* filter = nullptr;
        
        id block = ^{
            if(processingContext != nil)
                [processingContext makeCurrent];
            else
                [CGESharedGLContext useGlobalGLContext];
           
            CGEImageFilterInterface* customFilter = cgeCreateCustomFilterByType(type);
            
            if(customFilter == nullptr)
            {
                CGE_NSLog(@"create Custom filter failed!\n");
                return;
            }
            
            filter = new CGEMutipleEffectFilter();
            filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
            filter->initCustomize();
            filter->addFilter(customFilter);
            filter->setIntensity(intensity);            
        };
        
        if(processingContext == nil)
        {
            [CGESharedGLContext globalSyncProcessingQueue:block];
        }
        else
        {
            [processingContext syncProcessingQueue:block];
        }
        
        return filter;
    }
    

    UIImage* cgeFilterUIImage_CustomFilters(UIImage* uiimage, CustomFilterType type, float intensity, CGESharedGLContext* processingContext)
    {
        if(type < 0 || type >= CGE_FILTER_TOTAL_NUMBER || intensity == 0.0f || uiimage == nil)
            return uiimage;
        
        __block UIImage* dstImg = nil;
        
        id block = ^{
            if(processingContext != nil)
                [processingContext makeCurrent];
            else
                [CGESharedGLContext useGlobalGLContext];
            
            CGEImageHandlerIOS handler;
            
            if(!handler.initWithUIImage(uiimage, true))
            {
                CGE_LOG_ERROR("Init handler failed!!!!\n");
                return ;
            }
            
            CGEImageFilterInterface* CustomFilter = cgeCreateCustomFilterByType(type);
            
            if(CustomFilter == nullptr)
            {
                CGE_NSLog(@"create Custom filter failed!\n");;
                return;
            }
            
            CGEMutipleEffectFilter* filter = new CGEMutipleEffectFilter();
            filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
            filter->initCustomize();
            filter->addFilter(CustomFilter);
            filter->setIntensity(intensity);
            
            handler.addImageFilter(filter);
            handler.processingFilters();
            
            dstImg = handler.getResultUIImage();
        };
        
        if(processingContext == nil)
        {
            [CGESharedGLContext globalSyncProcessingQueue:block];
        }
        else
        {
            [processingContext syncProcessingQueue:block];
        }
        
        return dstImg;
    }

}
