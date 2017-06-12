/*
 * cgeImageViewHandler.h
 *
 *  Created on: 2015-11-18
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import <GLKit/GLKit.h>
#import "cgeSharedGLContext.h"

#define CGE_IMAGEVIEW_IMAGEHANDLER_IOS CGEImageHandlerIOS

typedef enum CGEImageViewDisplayMode
{
    CGEImageViewDisplayModeScaleToFill,
    CGEImageViewDisplayModeAspectFill,
    CGEImageViewDisplayModeAspectFit,
    CGEImageViewDisplayModeDefault = CGEImageViewDisplayModeScaleToFill
}CGEImageViewDisplayMode;

@interface CGEImageViewHandler : NSObject

@property (weak, nonatomic) GLKView* glkView;
@property (nonatomic, readonly)CGESharedGLContext* sharedContext;
@property (nonatomic)CGSize imageSize;
@property (nonatomic)float currentIntensity;

// 初始化接口

- (id)initWithGLKView:(GLKView*)glkView;
- (id)initWithGLKView:(GLKView*)glkView withImage:(UIImage*)image;//image 将作为默认使用图像(附加滤镜等)

#pragma mark - 滤镜设定相关接口

//通用滤镜配置接口
- (BOOL)setFilterWithConfig :(const char*) config;

//扩展用法, 设置的filter必须与当前view在同一OpenGL环境下， 否则将出错
- (BOOL)setFilter :(void*)filter;
- (BOOL)setFilterWithWrapper :(void*)filter;

- (void)flush; //flush filters.

//通用滤镜强度设定接口， 取值范围 [0, 1]
//注意， 当强度低于1时取得相反效果， 强度高于1时得到增强效果(某些滤镜无效， 如Lerp blur
- (void)setFilterIntensity :(float)value;

#pragma mark - 图片相关接口

- (BOOL)setUIImage:(UIImage*) image; //切换图像
- (UIImage*)resultImage; //获取计算结果

#pragma mark - 显示相关的接口

- (void)setViewDisplayMode :(CGEImageViewDisplayMode)mode;

#pragma mark - 其他接口

//清除view
- (void)clear;

//辅助接口 (子类使用, 非对外)
- (void*)_getHandler;
- (void)_setupView;


@end
