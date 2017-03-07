/*
 * cgeCameraDevice.h
 *
 *  Created on: 2015-8-23
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

// 本文件(cgeVideoCamera.h) 部分代码参考自: https://github.com/BradLarson/GPUImage/blob/master/framework/Source/GPUImageVideoCamera.h
// 对外接口， 添加较多中文注释

#ifndef cge_cgeCamera_h
#define cge_cgeCamera_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>

@protocol CGECameraDeviceOutputDelegate <NSObject>

@required
-(void) dealVideoSampleBuffer :(CMSampleBufferRef) buffer;

@optional
-(void) dealAudioSampleBuffer :(CMSampleBufferRef) buffer;

@end

@interface CGECameraDevice : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate,
                                    AVCaptureAudioDataOutputSampleBufferDelegate>
{
    BOOL _capturePaused;
    AVCaptureDevice* _microphoneDevice;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    
    __unsafe_unretained id<CGECameraDeviceOutputDelegate> _outputDelegate;
}

@property(nonatomic, assign, readonly) CGSize cameraResolution; // 相机当前使用的分辨率
@property(readonly, retain, nonatomic) AVCaptureSession *captureSession; // 相机当前使用的 session
@property(readwrite) AVCaptureStillImageOutput *stillImageOutput; // 相机当前可用于拍照的 output

// This enables the capture session preset to be changed on the fly
// (相机当前使用的 session preset， 在相机已经启动的情况下对 captureSessionPreset 进行赋值可以实时改变当前的相机分辨率)
@property (readwrite, nonatomic, copy) NSString *captureSessionPreset;

// This sets the frame rate of the camera (iOS 5 and above only)
// Setting this to 0 or below will set the frame rate back to the default setting for a particular preset.
// 相机预览使用的分辨率， 在相机启动的情况下对 frameRate 进行赋值可以实时改变当前相机帧率
@property (readwrite) int32_t frameRate;

// Use this property to manage camera settings. Focus point, exposure point, etc.
@property(readonly) AVCaptureDevice *inputCamera;

///////////////////////////////////////////////////////////////////////

#pragma mark - 初始化相关接口

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;

// Add audio capture to the session. Adding inputs and outputs freezes the capture session momentarily, so you
// can use this method to add the audio inputs and outputs early, if you're going to set the audioEncodingTarget
// later. Returns YES is the audio inputs and outputs were added, or NO if they had already been added.

- (BOOL)addAudioInputsAndOutputs;

// Remove the audio capture inputs and outputs from this session. Returns YES if the audio inputs and outputs
// were removed, or NO is they hadn't already been added.

- (BOOL)removeAudioInputsAndOutputs;

// Tear down the capture session

- (void)removeInputsAndOutputs;

#pragma mark - 相机状态获取相关接口

- (BOOL)captureIsRunning;    // 相机是否正在预览

- (AVCaptureDevicePosition)cameraPosition; // 获取当前摄像头位置（AVCaptureDevicePositionBack or AVCaptureDevicePositionFront)

- (AVCaptureConnection *)videoCaptureConnection; // 获取当前的 connection

+ (BOOL)isBackFacingCameraPresent;
+ (BOOL)hasFrontFacingCameraPresent;
+ (BOOL)isHeadphoneAvailable;

#pragma mark - 相机设定相关接口

- (void)startCameraCapture;  // 启动相机预览
- (void)stopCameraCapture;   // 停止相机预览

- (void)pauseCameraCapture;  // 暂停相机预览
- (void)resumeCameraCapture; // 继续相机预览

- (BOOL)switchCamera;        // 切换前后摄像头 (有可能失败， 例: iPhone4s 后置摄像头支持720P， 但是前置摄像头不支持， 从后置摄像头切到前置将会失败

- (AVCaptureFlashMode)flashMode;

- (BOOL)setFlashMode :(AVCaptureFlashMode)flashMode; //设定闪光灯模式

- (AVCaptureTorchMode)torchMode;

- (BOOL)setTorchMode :(AVCaptureTorchMode)torchMode; //设定手电筒模式

- (AVCaptureFocusMode)focusMode;

- (BOOL)setFocusMode :(AVCaptureFocusMode)focusMode; //设定对焦模式

- (AVCaptureExposureMode)exposureMode;

- (BOOL)setExposureMode :(AVCaptureExposureMode)exposureMode; //设定曝光模式

// 点按对焦功能, 调用后对焦模式自动切换为 AVCaptureFocusModeAutoFocus
// CGPoint 取值范围: [0, 1]
// 返回值 YES 表示对焦成功, NO 表示失败
- (BOOL)focusPoint: (CGPoint)point;

#pragma mark - 其他设置

- (id)delegate;
- (void)setDelegate: (id<CGECameraDeviceOutputDelegate>)delegate;

- (void)cleanup;

- (void)flushResolution;

@end

#endif
