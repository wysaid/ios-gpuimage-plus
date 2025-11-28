/*
 * cgeDeformFilterWrapper.h
 *
 *  Created on: 2024-11-28
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 *  Description: Objective-C wrapper for liquify/deform filter
 */

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "cgeSharedGLContext.h"

@interface CGEDeformFilterWrapper : NSObject

@property (nonatomic, readonly) void* nativeAddress;

/**
 * Create a deform filter wrapper
 * @param width The real width of the picture in pixels
 * @param height The real height of the picture in pixels
 * @param stride Set the mesh in real pixels, the mesh size would be (width / stride, height / stride)
 * @return CGEDeformFilterWrapper instance or nil if creation failed
 */
+ (instancetype)createWithWidth:(float)width height:(float)height stride:(float)stride;

/**
 * Release the native filter
 * @param shouldDeleteNativeFilter If NO, the native filter will not be deleted (useful when the filter is bound to an image handler)
 */
- (void)releaseWithDeleteNativeFilter:(BOOL)shouldDeleteNativeFilter;

/**
 * Restore the mesh to its original state
 */
- (void)restore;

/**
 * Restore the mesh with intensity
 * @param intensity Range [0, 1]. 0 for no effect and 1 for origin.
 */
- (void)restoreWithIntensity:(float)intensity;

/**
 * Forward deform the mesh
 * @param startX Start X position of the cursor
 * @param startY Start Y position of the cursor
 * @param endX End X position of the cursor
 * @param endY End Y position of the cursor
 * @param w Canvas width (the max 'x' of the cursor)
 * @param h Canvas height (the max 'y' of the cursor)
 * @param radius The deform radius in real pixels
 * @param intensity Range (0, 1], 0 for origin. Better not more than 0.5
 */
- (void)forwardDeformWithStartX:(float)startX startY:(float)startY endX:(float)endX endY:(float)endY width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity;

/**
 * Restore mesh at a specific point
 * @param x X position of the cursor
 * @param y Y position of the cursor
 * @param w Canvas width
 * @param h Canvas height
 * @param radius The restore radius in real pixels
 * @param intensity Restore intensity
 */
- (void)restoreWithPointX:(float)x y:(float)y width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity;

/**
 * Bloat (expand) deform at a specific point
 * @param x X position of the cursor
 * @param y Y position of the cursor
 * @param w Canvas width
 * @param h Canvas height
 * @param radius The bloat radius in real pixels
 * @param intensity Bloat intensity
 */
- (void)bloatDeformWithX:(float)x y:(float)y width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity;

/**
 * Wrinkle (shrink) deform at a specific point
 * @param x X position of the cursor
 * @param y Y position of the cursor
 * @param w Canvas width
 * @param h Canvas height
 * @param radius The wrinkle radius in real pixels
 * @param intensity Wrinkle intensity
 */
- (void)wrinkleDeformWithX:(float)x y:(float)y width:(float)w height:(float)h radius:(float)radius intensity:(float)intensity;

/**
 * Set the maximum number of undo steps
 * @param undoSteps Maximum number of undo steps
 */
- (void)setUndoSteps:(int)undoSteps;

/**
 * Check if undo is available
 * @return YES if undo is available
 */
- (BOOL)canUndo;

/**
 * Check if redo is available
 * @return YES if redo is available
 */
- (BOOL)canRedo;

/**
 * Undo the last deform operation
 * @return YES if undo was successful
 */
- (BOOL)undo;

/**
 * Redo the last undone deform operation
 * @return YES if redo was successful
 */
- (BOOL)redo;

/**
 * Push the current deform step to the undo stack
 * @return YES if push was successful, NO if the steps count meets the max step limit
 */
- (BOOL)pushDeformStep;

/**
 * Show or hide the mesh overlay
 * @param show YES to show the mesh, NO to hide it
 */
- (void)showMesh:(BOOL)show;

@end
