/*
 * cgeFrameRecorder.h
 *
 *  Created on: 2015-12-1
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

// 主要作为辅助类使用

#ifndef _CGE_FRAME_RECORDER_H_
#define _CGE_FRAME_RECORDER_H_

#import <Foundation/Foundation.h>
#import "cgeVideoWriter.h"
#import "cgeFrameRenderer.h"

@interface CGEFrameRecorder : CGEFrameRenderer

@property(nonatomic, readonly) NSURL* outputVideoURL;
@property(nonatomic, readonly) NSURL* cacheVideoURL;

@property(nonatomic, weak) id<CGEFrameUpdateDelegate> updateDelegate;
@property(nonatomic, readonly) CGEVideoWriter* videoWriter;
@property(nonatomic, readonly) BOOL isRecording;
@property(nonatomic) BOOL shouldPassthroughAudio;

#pragma mark - 初始化相关

- (id)initWithContext :(CGESharedGLContext*)sharedContext;

// 手动调用释放
- (void)clear;


#pragma mark - 录像相关接口

/*
 For example:
 
 outputSettings = @{
 
 AVVideoCodecKey : AVVideoCodecH264,
 AVVideoWidthKey : @(_videoSize.width),
 AVVideoHeightKey : @(_videoSize.height),
 AVVideoCompressionPropertiesKey : @{ AVVideoAverageBitRateKey : @(1650000),
 AVVideoExpectedSourceFrameRateKey : @(30),
 AVVideoMaxKeyFrameIntervalKey : @(30),
 "EncodingLiveVideo" : @(YES), //此处必填， 相机实时录制必然为 YES, 已录制视频转录应该为 NO
 
 "mute" : @(NO)  //可选参数， 可不填
 
 }
 
 */

- (void)startRecording :(NSURL*)videoURL size:(CGSize)videoSize;
- (void)startRecording :(NSURL*)videoURL size:(CGSize)videoSize outputSetting:(NSDictionary*)ouputSetting;
- (void)endRecording :(void (^)(void))completionHandler; //默认 压缩程度 中等
- (void)endRecording :(void (^)(void))completionHandler withCompressionLevel:(int)level; //level 取值范围为 [0, 3], 0为不压缩， 1 清晰度较高， 文件较大, 2 中等, 3 清晰度较低， 文件较小

- (void)endRecording:(void (^)(void))completionHandler withQuality:(NSString*)quality shouldOptimizeForNetworkUse:(BOOL)shouldOptimize; //quality为 AVAssetExportPreset*

- (void)cancelRecording;

@end


#endif