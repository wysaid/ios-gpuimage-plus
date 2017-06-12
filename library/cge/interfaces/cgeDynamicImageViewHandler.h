/*
 * cgeDynamicImageViewHandler.h
 *
 *  Created on: 2015-12-28
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */


#import "cgeImageViewHandler.h"

//不适于图片帧特别多且图片分辨率较大的情况(当图片帧过多时将导致内存占用过多)

@interface CGEDynamicImageViewHandler : CGEImageViewHandler

@property (nonatomic)int currentImageIndex;
- (size_t)totalImages;

#pragma mark - 图片相关接口

/*
 
 imageConfig (NSDictionary*)
 
 @{
 
         @"images" : (NSArray*)images,     //要用到的图片 (UIImage*), 分辨率以第一张为准
     @"delayTimes" : (NSArray*)delayTimes, //每一张图片的单独持续显示时间 (float), 单位 秒 (与 stableDelayTime 二选一)
@"stableDelayTime" : (float)delayTime,     //所有图片的持续显示时间 (与 delayTimes 二选一)
 
 }
 
*/

- (BOOL)setUIImagesWithConfig: (NSDictionary*)imageConfig startAnimation:(BOOL)doAnimation;

- (BOOL)setGifImage:(CFURLRef)gifUrl;

- (BOOL)saveAsGif:(NSURL*)gifUrl loopCount:(int)loopCount; //loopCount <= 0 表示不断循环

/*
 
 getResultImages返回值: (NSDictionary*)
 
 @{
        @"images" : (NSArray*)images,     //结果图片 (UIImage*)
    @"delayTimes" : (NSArray*)delayTimes, //每一张图片的单独持续显示时间 (float), 单位 秒

  }
 
*/

- (NSDictionary*)getResultImages;

#pragma mark - 显示相关的接口

- (BOOL)startAnimation; //当图像少于2张时无法启动动画。
- (void)stopAnimation;

- (BOOL)jumpToFrame:(int)frameIndex; //直接跳转到指定帧 frameIndex 介于 [0, totalImages-1]




@end
