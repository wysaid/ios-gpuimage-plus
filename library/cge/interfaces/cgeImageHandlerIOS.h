/*
 * cgeImageHandlerIOS.h
 *
 *  Created on: 2015-8-23
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#ifndef __cge__cgeImageHandlerIOS__
#define __cge__cgeImageHandlerIOS__

#import <UIKit/UIKit.h>
#include "cgeImageHandler.h"

namespace CGE
{
    class CGEImageHandlerIOS : public CGE::CGEImageHandler
    {
    public:
        
        CGEImageHandlerIOS();
        ~CGEImageHandlerIOS();
        
        bool initWithUIImage(UIImage* uiimage, bool useImageBuffer = true, bool enableRevision = false);
        
        UIImage* getResultUIImage();
        
        void processingFilters();
        
        void swapBufferFBO();
        
        void enableImageBuffer(bool useBuffer);
        bool isImageBufferEnabled() { return m_imageBuffer != nullptr;}
        
    protected:
        
        unsigned char* m_imageBuffer;
        int m_imageBufferLen;
        CGFloat m_imageScale;
    };

}


#endif /* defined(__cge__cgeImageHandlerIOS__) */
