/*
 * cgeVideoFrameRecorder.h
 *
 *  Created on: 2015-10-10
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import <Foundation/Foundation.h>
#import "cgeFrameRecorder.h"
#import "cgeCommonDefine.h"

// 'cgeFrameRecorder' is used for offscreen processing, no sounds play back. (Sounds would be saved in the result)

@class CGEVideoFrameRecorder;

@protocol CGEVideoFrameRecorderDelegate <NSObject>

@required
- (void)videoReadingComplete:(CGEVideoFrameRecorder*)videoFrameRecorder;

@optional
- (void)videoResolutionChanged: (CGSize)size;

@end

@interface CGEVideoFrameRecorder : CGEFrameRecorder

@property(nonatomic, readonly) AVAssetReader* videoAssetReader;
@property(atomic) BOOL videoLoopRunning;
@property(atomic) BOOL audioLoopRunning;
@property(nonatomic) BOOL mute;

//YES 表示使用实际播放速度进行播放
//NO 表示使用最大速度进行播放(主要用于后台处理)
@property(nonatomic) BOOL playAtActualSpeed;

// 播放进度, 范围 [0, 1]
@property(nonatomic) float progress;

// 总时长
@property(nonatomic) CMTime duration;

@property(nonatomic) CGSize videoResolution;

@property(nonatomic, weak) id<CGEVideoFrameRecorderDelegate> videoFrameRecorderDelegate;

- (id)initWithContext:(CGESharedGLContext *)sharedContext;

- (void)setupWithAsset:(AVAsset*)asset completionHandler:(void (^)(BOOL))block;
- (void)setupWithURL:(NSURL*)url completionHandler:(void (^)(BOOL))block;

- (void)start; //启动 (注意， 本类不提供暂停继续快进等功能， 一旦停止， 只能重新启动)
- (void)end;   //停止, 直接调用 end 结束时，(videoFrameRecorderDelegate videoReadingComplete:) 不会被调用


- (void)startRecording :(NSURL*)videoURL; // 启动录制， 并使用视频完整分辨率保存 (必须在 start之后调用)

//- (void)setTimeline:(void*)timeline; //特殊接口， timeline类型必须为 CGE::TimeLine.

//////////////////////////////

+ (double)fpsLimit;
+ (void)setFPSLimit:(double)fps;


/*
 
 videoConfig (NSDictionary*)
 
 @{
      @"sourceAsset" : (AVAsset*)sourceAsset,           //输入视频Asset(Asset和URL 任选其一)
        @"sourceURL" : (NSURL*)sourceURL,               //输入视频URL  (Asset和URL 任选其一)
     @"filterConfig" : (NSString*)filterConfig,         //滤镜配置 (可不写)
  @"filterIntensity" : (float)filterIntensity,          //滤镜强度 (不写默认 1.0, 范围[0, 1])
       @"blendImage" : (UIImage*)blendImage,            //每一帧混合图片 (可不写)
        @"blendMode" : (CGETextureBlendMode)blendMode,  //混合模式 (默认 CGE_BLEND_MIX 当blendImage不存在时无效)
   @"blendIntensity" : (float)blendIntensity            //混合强度 (不写默认 1.0, 范围[0, 1])
             @"mute" : (BOOL)isMuted                    //是否静音 (不写默认保留声音)
 }
 
 */

+ (instancetype)generateVideoWithFilter:(NSURL*)ouputVideoUrl      //输出视频
                                   size:(CGSize)videoSize          //输出视频大小 (当videoSize任意边 <= 0 时， 使用原始视频大小)
                           withDelegate:(id<CGEVideoFrameRecorderDelegate>)delegate
                            videoConfig:(NSDictionary*)videoConfig;

@end




