/*
 * cgeVideoCameraViewHandler.h
 *
 *  Created on: 2015-9-6
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

// 对外接口， 添加较多中文注释

#import <GLKit/GLKit.h>
#import "cgeCameraFrameRecorder.h"

@interface CGECameraViewHandler : NSObject<CGEFrameUpdateDelegate>

@property(nonatomic, readonly) CGECameraFrameRecorder* cameraRecorder;

@property(nonatomic) BOOL shouldResetViewport;

- (id)initWithGLKView:(GLKView*)glkView;

#pragma mark - 滤镜设定相关接口

//通用滤镜配置接口
- (void)setFilterWithConfig :(const char*) config;

//通用滤镜强度设定接口， 取值范围 [0, 1]
//注意， 当强度低于1时取得相反效果， 强度高于1时得到增强效果(某些滤镜无效， 如Lerp blur
- (void)setFilterIntensity :(float)value;

#pragma mark - 相机设定相关接口

- (AVCaptureDevicePosition)cameraPosition;
- (BOOL)switchCamera :(BOOL)isFrontCameraMirrored;
- (AVCaptureFlashMode)getFlashMode;
- (BOOL)setCameraFlashMode :(AVCaptureFlashMode)flashMode;
- (AVCaptureTorchMode)getTorchMode;
- (BOOL)setTorchMode :(AVCaptureTorchMode)torchMode;

- (BOOL)setupCamera; //默认后置摄像头
- (BOOL)setupCamera :(NSString*)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition isFrontCameraMirrored:(BOOL)isFrontCameraMirrored authorizationFailed:(void (^)(void))authorizationFailed;
- (BOOL)focusPoint: (CGPoint)point; //点按对焦, point 范围 [0, 1]， focus位置在显示区域的相对位置

- (CGECameraDevice*) cameraDevice;

- (void)stopCameraSync;

#pragma mark - 拍照相关接口

- (void)setCameraSessionPreset:(NSString*)sessionPreset;

- (void)takePicture :(void (^)(UIImage*))block filterConfig:(const char*)config filterIntensity:(float)intensity isFrontCameraMirrored:(BOOL)mirrored;

- (void)takeShot :(void (^)(UIImage*))block;

#pragma mark - 录像相关接口

- (void)startRecording :(NSURL*)videoURL size:(CGSize)videoSize;
- (void)startRecording :(NSURL*)videoURL size:(CGSize)videoSize cropArea:(CGRect)cropArea; //cropArea参见cgeVideoWriter相关解释

- (void)endRecording :(void (^)(void))completionHandler;
- (void)endRecording :(void (^)(void))completionHandler withCompressionLevel:(int)level;//level 取值范围为 [0, 3], 0为不压缩， 1 清晰度较高，
- (void)endRecording:(void (^)(void))completionHandler withQuality:(NSString*)quality shouldOptimizeForNetworkUse:(BOOL)shouldOptimize; //quality为 AVAssetExportPreset*

- (void)cancelRecording;
- (BOOL)isRecording;

#pragma mark - mask相关接口

//mask设定中， 第一个参数填 nil 或者0 表示不使用mask
- (void)setMaskUIImage :(UIImage*)image;
- (void)setMaskTexture :(GLuint)maskTexture textureAspectRatio:(float)aspectRatio;
- (BOOL)isUsingMask;

//全局滤镜相关
- (void)enableGlobalFilter :(const char*)config;
- (void)enableFaceBeautify :(BOOL)shouldDo; //FaceBeautify 与 GlobalFilter 属于同类模块， 不可同时开启
- (void)setGlobalFilterIntensity :(float)intensity;
- (float)globalFilterIntensity;

- (BOOL)isGlobalFilterEnabled;

#pragma mark - 其他接口

//- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect;
- (void)clear;

- (void)fitViewSizeKeepRatio :(BOOL)shouldFit;

@end
