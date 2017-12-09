/*
 * cgeProcessingContext.m
 *
 *  Created on: 2015-9-17
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import "cgeProcessingContext.h"

#if defined(_CGE_GENERAL_ERROR_TEST_ ) && _CGE_GENERAL_ERROR_TEST_

static int s_totalSharedContextNum = 0;

#define CGE_LEAK_TEST_CODE(...) __VA_ARGS__

static void contextCreate()
{
    ++s_totalSharedContextNum;
    CGE_NSLog(@"‼️‼️context created, total num: %d\n", s_totalSharedContextNum);
}

static void contextRelease()
{
    --s_totalSharedContextNum;
    CGE_NSLog(@"⛔️⛔️context released, total num: %d\n", s_totalSharedContextNum);
}

#define CONTEXT_CREATE contextCreate()
#define CONTEXT_RELEASE contextRelease()

#else

#define CONTEXT_CREATE
#define CONTEXT_RELEASE

#endif

@interface CGEProcessingContext()
{
}
@end

@implementation CGEProcessingContext

- (id)init
{
    if((self = [super init]) != nil)
    {
        CONTEXT_CREATE;
        
        _contextKey = (__bridge void *)(self);
        _contextQueue = dispatch_queue_create("org.wysaid.cge", DISPATCH_QUEUE_SERIAL );
        dispatch_queue_set_specific(_contextQueue, _contextKey, (__bridge void *)self, NULL);
        
    }
    return  self;
}

- (void)dealloc
{
    _contextQueue = nil;
    _contextKey = nil;
    
    CONTEXT_RELEASE;
}

- (void)syncProcessingQueue:(void (^)(void))block
{
    CGE_NSAssert(block != nil, @"block could not be nil!!");
    
    if (dispatch_get_specific(_contextKey))
    {
        block();
        CGE_NSLog(@"‼️‼️Repeat processing block queue!");
    }
    else
    {
        dispatch_sync(_contextQueue, block);
    }

}

- (void)asyncProcessingQueue:(void (^)(void))block
{
    CGE_NSAssert(block != nil, @"block could not be nil!!");
    
    if (dispatch_get_specific(_contextKey))
    {
        block();
        CGE_NSLog(@"‼️‼️Repeat processing block queue!");
    }
    else
    {
        dispatch_async(_contextQueue, block);
    }
}

/////////////////////////////////////////////

+ (void)mainSyncProcessingQueue:(void (^)(void))block
{
    if([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

+ (void)mainASyncProcessingQueue:(void (^)(void))block
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:block];
}

CGE_UNEXPECTED_ERR_MSG
(
+ (int)refCount
{
    return s_totalSharedContextNum;
}
)

@end
