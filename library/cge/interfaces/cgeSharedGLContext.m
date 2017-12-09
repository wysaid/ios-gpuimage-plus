/*
 * cgeSharedGLContext.m
 *
 *  Created on: 2015-7-11
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeSharedGLContext.h"
#import <OpenGLES/ES2/gl.h>

#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

static CGESharedGLContext* s_globalContext = nil;

@implementation CGESharedGLContext

- (void)dealloc
{
    CGE_NSLog(@"CGEShared Context release...");
    _context = nil;
}

- (id)init
{
    return [self initWithContext:nil];
}

- (instancetype)initWithShareGroup:(EAGLSharegroup *)shareGroup
{
    self = [super init];
    if (self)
    {
        [self syncProcessingQueue:^{
            if(shareGroup)
                _context = [CGESharedGLContext createContext:shareGroup];
            else
                _context = [CGESharedGLContext createContext:nil];
        }];
    }
    
    return self;
}

- (id)initWithContext:(CGESharedGLContext*)sharedContext
{
    self = [super init];
    if (self)
    {
        [self syncProcessingQueue:^{
            if(sharedContext)
                _context = [CGESharedGLContext createContext:[[sharedContext context] sharegroup]];
            else
                _context = [CGESharedGLContext createContext:nil];
        }];
    }
    
    return self;
}

//in main thread
- (id)initAsGlobalContext :(EAGLContext*)context
{
    self = [super init];
    _context = context;
    
    return self;
}

+ (EAGLContext *)createContext : (EAGLSharegroup *)sharedgroup
{
    EAGLContext *context;
    
    if(sharedgroup == nil)
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    else
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:sharedgroup];
    
    CGE_NSAssert(context != nil, @"Unable to create an OpenGL ES 2.0 context. Requires OpenGL ES 2.0 support to work.");
    return context;
}

- (void)makeCurrent
{
    [EAGLContext setCurrentContext:_context];
}

//////////////////////////////////////////////////////

+ (instancetype)globalGLContext
{
    if(s_globalContext == nil)
    {
        EAGLContext* ctx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        CGE_NSAssert(ctx != nil, @"Alloc EAGLContext failed!\n");
        s_globalContext = [[CGESharedGLContext alloc] initAsGlobalContext:ctx];
    }
    
    return s_globalContext;
}

+ (BOOL)isGlobalGLContextExist
{
    return s_globalContext != nil;
}

+ (instancetype)bindGlobalGLContext:(EAGLContext *)context
{
    [self clearGlobalGLContext];
    if(context != nil)
    {
        s_globalContext = [[CGESharedGLContext alloc] initAsGlobalContext:context];
    }
    
    return s_globalContext;
}

+ (void)useGlobalGLContext
{
    [[CGESharedGLContext globalGLContext] makeCurrent];
}

+ (void)clearGlobalGLContext
{
    if(s_globalContext != nil)
    {
        CGE_UNEXPECTED_ERR_MSG
        (
         if([CGESharedGLContext refCount] != 1)
         {
             CGE_NSLog(@"\n❗️❗️❗️❗️❗️\n\n\nYou're clearing global context when other contexts still exist!\n这种情况可能会产生错误, 如果确实没有问题, 请忽略本条消息\n\n❗️❗️❗️❗️❗️\n");
         }
         )
        
        [s_globalContext setContext:nil];
        s_globalContext = nil;
        [EAGLContext setCurrentContext:nil];
    }
}

+ (void)globalSyncProcessingQueue:(void (^)(void))block
{
    CGE_NSAssert(block != nil, @"block could not be nil!!");
    
    if (dispatch_get_specific([CGESharedGLContext globalGLContext]->_contextKey))
    {
        block();
        CGE_NSLog(@"‼️‼️Repeat processing block queue!");
    }
    else
    {
        dispatch_sync([[CGESharedGLContext globalGLContext] contextQueue], block);
    }
}

+ (void)globalAsyncProcessingQueue:(void (^)(void))block
{
    CGE_NSAssert(block != nil, @"block could not be nil!!");
    
    if (dispatch_get_specific([CGESharedGLContext globalGLContext]->_contextKey))
    {
        block();
        CGE_NSLog(@"‼️‼️Repeat processing block queue!");
    }
    else
    {
        dispatch_async([[CGESharedGLContext globalGLContext] contextQueue], block);
    }
}

+(instancetype)createSharedContext:(CGESharedGLContext*)sharedContext
{
    return [[CGESharedGLContext alloc] initWithContext:sharedContext];
}

+(instancetype)createGlobalSharedContext
{
    return [[CGESharedGLContext alloc] initWithContext:[CGESharedGLContext globalGLContext]];
}

@end
