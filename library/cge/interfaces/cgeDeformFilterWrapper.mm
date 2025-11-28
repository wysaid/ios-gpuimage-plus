/*
 * cgeDeformFilterWrapper.mm
 *
 *  Created on: 2024-11-28
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 *  Description: Objective-C wrapper for liquify/deform filter
 */

#import "cgeDeformFilterWrapper.h"
#import "cgeLiquidationFilter.h"
#import "cgeVec.h"

using namespace CGE;

@interface CGEDeformFilterWrapper()
{
    CGELiquidationFilter* _filter;
}
@end

@implementation CGEDeformFilterWrapper

+ (instancetype)createWithWidth:(float)width height:(float)height stride:(float)stride
{
    // Validate input parameters
    if (width <= 0 || height <= 0 || stride <= 0) {
        NSLog(@"CGEDeformFilterWrapper.create failed: Invalid parameters (width: %.2f, height: %.2f, stride: %.2f). All values must be positive.", width, height, stride);
        return nil;
    }
    
    CGEDeformFilterWrapper* wrapper = [[CGEDeformFilterWrapper alloc] initWithWidth:width height:height stride:stride];
    if (wrapper && wrapper->_filter == nullptr) {
        wrapper = nil;
        NSLog(@"CGEDeformFilterWrapper.create failed!");
    }
    return wrapper;
}

- (instancetype)initWithWidth:(float)width height:(float)height stride:(float)stride
{
    self = [super init];
    if (self) {
        _filter = new CGELiquidationFilter();
        if (!_filter->initWithMesh(width, height, stride)) {
            delete _filter;
            _filter = nullptr;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_filter != nullptr) {
        delete _filter;
        _filter = nullptr;
    }
}

- (void*)nativeAddress
{
    return _filter;
}

- (void)releaseWithDeleteNativeFilter:(BOOL)shouldDeleteNativeFilter
{
    if (_filter != nullptr) {
        if (shouldDeleteNativeFilter) {
            delete _filter;
        }
        _filter = nullptr;
    }
}

- (void)restore
{
    if (_filter != nullptr) {
        _filter->restoreMesh();
    }
}

- (void)restoreWithIntensity:(float)intensity
{
    if (_filter != nullptr) {
        _filter->restoreMeshWithIntensity(intensity);
    }
}

- (void)forwardDeformWithStartX:(float)startX startY:(float)startY endX:(float)endX endY:(float)endY width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity
{
    if (_filter != nullptr) {
        _filter->forwardDeformMesh(Vec2f(startX, startY), Vec2f(endX, endY), w, h, radius, intensity);
    }
}

- (void)restoreWithPointX:(float)x y:(float)y width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity
{
    if (_filter != nullptr) {
        _filter->restoreMeshWithPoint(Vec2f(x, y), w, h, radius, intensity);
    }
}

- (void)bloatDeformWithX:(float)x y:(float)y width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity
{
    if (_filter != nullptr) {
        _filter->bloatMeshWithPoint(Vec2f(x, y), w, h, radius, intensity);
    }
}

- (void)wrinkleDeformWithX:(float)x y:(float)y width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity
{
    if (_filter != nullptr) {
        _filter->wrinkleMeshWithPoint(Vec2f(x, y), w, h, radius, intensity);
    }
}

- (void)setUndoSteps:(int)undoSteps
{
    if (_filter != nullptr) {
        _filter->setUndoSteps(undoSteps);
    }
}

- (BOOL)canUndo
{
    if (_filter != nullptr) {
        return _filter->canUndo();
    }
    return NO;
}

- (BOOL)canRedo
{
    if (_filter != nullptr) {
        return _filter->canRedo();
    }
    return NO;
}

- (BOOL)undo
{
    if (_filter != nullptr) {
        return _filter->undo();
    }
    return NO;
}

- (BOOL)redo
{
    if (_filter != nullptr) {
        return _filter->redo();
    }
    return NO;
}

- (BOOL)pushDeformStep
{
    if (_filter != nullptr) {
        return _filter->pushMesh();
    }
    return NO;
}

- (void)showMesh:(BOOL)show
{
    if (_filter != nullptr) {
        _filter->showMesh(show);
    }
}

@end
