/*
 * cgeCameraFrameRecorder.h
 *
 *  Created on: 2015-8-31
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#ifndef __cge__cgeCameraFrameRecorder__
#define __cge__cgeCameraFrameRecorder__

#import <Foundation/Foundation.h>
#import "cgeCameraDevice.h"
#import "cgeFrameRecorder.h"

@interface CGECameraFrameRecorder : CGEFrameRecorder<CGECameraDeviceOutputDelegate>

@property(nonatomic, weak, setter=setProcessingDelegate:) id<CGEFrameProcessingDelegate> processingDelegate;

@property(nonatomic, weak, setter=setExtraRenderingDelegate:) id<CGEFrameExtraRenderingDelegate> extraRenderingDelegate;

@property CGECameraDevice* cameraDevice;

@property(nonatomic) float maskAspectRatio;

#pragma mark - 初始化相关

- (id)initWithContext :(CGESharedGLContext*)sharedContext;

// 手动调用释放
- (void)clear;

#pragma mark - 相机相关接口

- (BOOL)setupCamera; //默认后置摄像头
- (BOOL)setupCamera :(NSString*)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition isFrontCameraMirrored:(BOOL)isFrontCameraMirrored authorizationFailed:(void (^)(void))authorizationFailed;
- (BOOL)switchCamera :(BOOL)isFrontCameraMirrored; //注意， 调用此处 switchCamera 会自动判断如果为前置摄像头，则左右反向(镜像)

- (BOOL)focusPoint: (CGPoint)point; //对焦

#pragma mark - 拍照相关接口

- (void)setPictureHighResolution:(BOOL)useHightResolution;

- (void)takePicture :(void (^)(UIImage*))block filterConfig:(const char*)config filterIntensity:(float)intensity isFrontCameraMirrored:(BOOL)mirrored;

#pragma mark - 其他接口

- (void)setGlobalFilter :(const char*)config;
- (void)setGlobalFilterIntensity :(float)intensity;
- (BOOL)hasGlobalFilter;
- (float)globalFilterIntensity;

- (void)enableVoicePlayback: (BOOL)shouldPlayback;
- (BOOL)hasVoicePlayback;
//刷新声音回放, 可以减小当前积累的延迟
- (void)flushVoicePlayback;

//注意， 当用户将app切到后台之后， 麦克风不可用， 需要重设设备!
- (void)resetVoicePlayback;

- (void)enableReverb: (BOOL)useReverb;
- (BOOL)hasReverb;

//reverb 取值范围 [0, 1] 默认 0 无效果
- (void)setReverbIntensity:(float)reverb;
//occlusion 取值范围 [-100, 0] 默认 0 无效果
- (void)setReverbOcclusion:(float)occlusion;
//obstruction 取值范围 [-100, 0] 默认 0 无效果
- (void)setReverbObstruction:(float)obstruction;

/* reverb room type presets for the ALC_ASA_REVERB_ROOM_TYPE property
 #define ALC_ASA_REVERB_ROOM_TYPE_SmallRoom             0
 #define ALC_ASA_REVERB_ROOM_TYPE_MediumRoom			1
 #define ALC_ASA_REVERB_ROOM_TYPE_LargeRoom             2
 #define ALC_ASA_REVERB_ROOM_TYPE_MediumHall			3
 #define ALC_ASA_REVERB_ROOM_TYPE_LargeHall             4
 #define ALC_ASA_REVERB_ROOM_TYPE_Plate                 5
 #define ALC_ASA_REVERB_ROOM_TYPE_MediumChamber         6
 #define ALC_ASA_REVERB_ROOM_TYPE_LargeChamber          7
 #define ALC_ASA_REVERB_ROOM_TYPE_Cathedral             8
 #define ALC_ASA_REVERB_ROOM_TYPE_LargeRoom2			9
 #define ALC_ASA_REVERB_ROOM_TYPE_MediumHall2           10
 #define ALC_ASA_REVERB_ROOM_TYPE_MediumHall3           11
 #define ALC_ASA_REVERB_ROOM_TYPE_LargeHall2			12
 */
- (void)setRoomType:(unsigned int)room;

@end


#endif /* defined(__cge__cgeFrameRecorder__) */
