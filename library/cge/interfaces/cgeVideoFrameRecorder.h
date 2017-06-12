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
@property(nonatomic) CMTimeRange timeRange;
@property(nonatomic) BOOL enableBackgroundBlurring;
@property(nonatomic) int videoOrientation;

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

- (void)setTimeline:(void*)timeline; //特殊接口， timeline类型必须为 CGE::TimeLine.

//////////////////////////////

+ (double)fpsLimit;
+ (void)setFPSLimit:(double)fps;


/*
 
 videoConfig (NSDictionary*)
 
 @{
      @"sourceAsset" : (AVAsset*)sourceAsset,           //输入视频Asset(Asset和URL 任选其一)
        @"sourceURL" : (NSURL*)sourceURL,               //输入视频URL  (Asset和URL 任选其一)
 
        @"timeRange" : @[start, during],                //输入视频截取其中一段(可选), 单位: 秒
   @"blurBackground" : @(YES),                          //是否显示模糊背景(仅当视频输入与输出分辨率不匹配时设置有效
 @"videoOrientation" : @(0),                            //视频朝向, 取值0,1,2,3 分别表示旋转0,90,180,270度
 
     @"filterConfig" : (NSString*)filterConfig,         //滤镜配置 (可不写)
  @"filterIntensity" : (float)filterIntensity,          //滤镜强度 (不写默认 1.0, 范围[0, 1])
       @"blendImage" : (UIImage*)blendImage,            //每一帧混合图片 (可不写)
        @"blendMode" : (CGETextureBlendMode)blendMode,  //混合模式 (默认 CGE_BLEND_MIX 当blendImage不存在时无效)
   @"blendIntensity" : (float)blendIntensity            //混合强度 (不写默认 1.0, 范围[0, 1])
             @"mute" : (BOOL)isMuted                    //是否静音 (不写默认保留声音)
 
        @"slideshow" : @[                               //增强型功能， 目前提供简单的slideshow动画支持. (暂未开放)
            {
             "image" : "instance of UIImage",
             //"imageFile" : "/path/of/image/xx.png or xx.jpg",
             
             "sprite" :
                 
                 [
                     {
                     "name" : "animSprite2d", //使用精灵类别
                     
                     "during" : ["startTime", "endTime"],
                     
                     "pos" : ["x", "y"],
                     
                     "scaling" : ["x", "y"],
                     
                     "rotation" : "rot",
 
                     "action" : [
 
                     // If you need more types, please push me a request.
                     // Currently support:
                     {
                     "name" : "uniformalpha",
                     "params" : ["startTime", "endTime", "alphaFrom", "alphaTo", "repeatTimes", "shouldInit"],
                     },
 
                     {
                     "name" : "uniformrotation",
                     "params" : ["startTime", "endTime", "rotFrom", "rotTo", "repeatTimes"],   //use radian, not degree!
                     },

                     {
                     "name" : "uniformscale",
                     "params" : ["startTime", "endTime", "scaleFrom", "scaleTo", "repeatTimes"],
                     }
 
                     ]
                     },
                     
                     {
                       ...
                     }
                 
                 ]
            },
 
	]
 }
 
 outputSettings = @{
 
 AVVideoCodecKey : AVVideoCodecH264,
 AVVideoCompressionPropertiesKey : @{ AVVideoAverageBitRateKey : @(1650000),
 AVVideoExpectedSourceFrameRateKey : @(30),
 AVVideoMaxKeyFrameIntervalKey : @(30),
 
 */

+ (instancetype)generateVideoWithFilter:(NSURL *)ouputVideoUrl size:(CGSize)videoSize withDelegate:(id<CGEVideoFrameRecorderDelegate>)delegate videoConfig:(NSDictionary *)videoConfig;

+ (instancetype)generateVideoWithFilter:(NSURL *)ouputVideoUrl size:(CGSize)videoSize withDelegate:(id<CGEVideoFrameRecorderDelegate>)delegate videoConfig:(NSDictionary *)videoConfig outputSetting:(NSDictionary*)outputSetting;

@end




