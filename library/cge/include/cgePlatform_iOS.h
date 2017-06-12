/*
 * cgePlatforms.h
 *
 *  Created on: 2013-12-31
 *      Author: Wang Yang
 *  Description: load some library and do some essential initialization before compiling.
 */

#ifndef CGEPLATFORMS_H_
#define CGEPLATFORMS_H_

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#if (defined(DEBUG) || defined(_DEBUG) || defined(_CGE_USE_LOG_ERR_))
#include <stdio.h>
#endif

#if (defined(DEBUG) || defined(_DEBUG))

#ifndef CGE_LOG_INFO
#define CGE_LOG_INFO(...) printf(__VA_ARGS__)
#endif

#ifndef CGE_LOG_CODE
#define CGE_LOG_CODE(...) __VA_ARGS__
#endif

#else

#ifndef CGE_LOG_INFO
#define CGE_LOG_INFO(...)
#endif

#ifndef CGE_LOG_CODE
#define CGE_LOG_CODE(...)
#endif

#endif

#if !defined(CGE_LOG_ERROR) && (defined(_CGE_USE_LOG_ERR_) || defined(DEBUG) || defined(_DEBUG))
#define CGE_LOG_ERROR(str, ...) \
do{\
fprintf(stderr, "\n❌❌❌\n" str "\n❌❌❌\n", ##__VA_ARGS__);\
fprintf(stderr, "%s:%d\n", __FILE__, __LINE__);\
}while(0)
#else 
#define CGE_LOG_ERROR(str, ...)
#endif

#ifndef CGE_UNEXPECTED_ERR_MSG

#define CGE_UNEXPECTED_ERR_MSG(...)

#else

//for important log msg
#define CGE_LOG_KEEP(...) printf(__VA_ARGS__)

#endif

#endif
