/*
 * cgeVideoWriter.h
 *
 *  Created on: 2015-9-14
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "cgeSharedGLContext.h"

@interface CGEVideoWriter : NSObject
{
    NSURL* _fileURL;
    NSString* _fileType;

    CVPixelBufferRef _pixelBufferRef;
    CVOpenGLESTextureRef _textureRef;
    CVOpenGLESTextureCacheRef _textureCacheRef;
}

@property(readonly, nonatomic) AVAssetWriter* assetWriter;

@property(readonly, nonatomic) AVAssetWriterInput* assetAudioInput;
@property(readonly, nonatomic) AVAssetWriterInput* assetVideoInput;
@property(readonly, nonatomic) AVAssetWriterInputPixelBufferAdaptor* assetPixelBufferInput;

@property(readonly, nonatomic) BOOL isRecording;
@property(readonly, nonatomic) CGSize videoSize;

@property(nonatomic, setter=setEncodingLiveVideo:) BOOL encodingLiveVideo;
@property(nonatomic) BOOL hasAudioTrack;
@property(nonatomic) BOOL shouldPassthroughAudio;
@property(nonatomic) BOOL audioEncodingOver, videoEncodingOver;


///////////////////////////////////////

- (void)clear;

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize;
- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize fileType:(NSString *)newFileType outputSettings:(NSDictionary *)outputSettings;
- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize fileType:(NSString *)newFileType outputSettings:(NSDictionary *)outputSettings usingContext:(CGESharedGLContext*)context;

- (void)setHasAudioTrack:(BOOL)hasAudioTrack audioSettings:(NSDictionary *)audioOutputSettings;

// Movie recording
- (void)startRecording;
- (void)startRecordingInOrientation:(CGAffineTransform)orientationTransform;
- (void)finishRecording;
- (void)finishRecordingWithCompletionHandler:(void (^)(void))handler;
- (void)cancelRecording;

- (void)processAudioBuffer: (CMSampleBufferRef)audioBuffer;

- (void)processFrameWithTexture :(GLuint)textureID atTime:(CMTime)frameTime;

#pragma mark - -- 辅助方法 --

//剪裁区域, 相对于原始比例大小, 范围 [0, 1]
//默认(0, 0, 1, 1),
- (void)setCropArea:(CGRect)cropArea;

// 视频压缩, 其中 successHandler 为压缩成功
// quality 包含的值为: AVAssetExportPresetLowQuality, AVAssetExportPresetMediumQuality, AVAssetExportPresetHighestQuality

+ (void)compressVideo :(NSURL*)outputURL inputURL:(NSURL*)inputURL quality:(NSString*)quality completionHandler:(void(^)(NSError*))handler;

+ (void)compressVideo :(NSURL*)outputURL inputURL:(NSURL*)inputURL quality:(NSString*)quality shouldOptimizeForNetworkUse:(BOOL)shouldOptimize completionHandler:(void(^)(NSError*))handler;

+ (void)compressVideoWithLowQuality :(NSURL*)outputURL inputURL:(NSURL*)inputURL completionHandler:(void(^)(NSError*))handler;
+ (void)compressVideoWithMediumQuality :(NSURL*)outputURL inputURL:(NSURL*)inputURL completionHandler:(void(^)(NSError*))handler;
+ (void)compressVideoWithHighQuality :(NSURL*)outputURL inputURL:(NSURL*)inputURL completionHandler:(void(^)(NSError*))handler;


// 通过大量图像数据以及一个音频文件生成一个视频
+ (void)generateVideoWithImages :(NSURL*)outputVideoURL         // 输出视频文件
                            size:(CGSize)videoSize              // 生成视频的分辨率
                          imgSrc:(NSArray*)imgArr               // UIImage数组(可以是文件名之类, 配合retrieveFunc使用)
                 imgRetrieveFunc:(UIImage* (^)(id))retrieveFunc // 当retrieveFunc 为nil 时， 表示imgArr数组包含的就是UIImage
                        audioURL:(NSURL*)audioURL                // 音频文件
                         quality:(NSString*)quality             // 生成视频质量 可选参数: AVAssetExportPresetLowQuality, AVAssetExportPresetMediumQuality, AVAssetExportPresetHighestQuality(当quality为nil时，将选择 AVAssetExportPresetHighestQuality)
                     secPerFrame:(double)secPerFrame           // 每一帧持续的毫秒数
               completionHandler:(void (^)(BOOL))block;         // 执行完之后的回调, 参数表示是否生成成功

+ (void)videoComposition:(NSURL*)outputVideoURL  inputVideoURL:(NSArray<NSURL*>*)inputVideoURLs inputAudioURL:(NSArray<NSURL*>*)inputAudioURLs keepVideoSound:(BOOL)keepVideoSound quality:(NSString*)quality completionHandler:(void (^)(BOOL))block;

//+ (void)videoCombination:(NSURL*)outputVideoURl inputVideos:(NSArray<NSURL*>*) inputVideos qualitu:(NSString*)quality 

// 使用系统自带方法对视频进行调速（音调不变， speed > 0)
+ (void)remuxingVideoWithTimescale:(NSURL*)outputVideoURL inputURL:(NSURL*)inputURL timescale:(double)timescale quality:(NSString*)quality completionHandler:(void (^)(BOOL success))block;

+ (void)reverseVideo:(NSURL*)outputVideoURL inputURL:(NSURL*)inputURL completionHandler:(void (^)(BOOL success))block;

+ (void)recompressVideo:(NSURL *)outputVideoURL inputURL:(NSURL *)inputVideo setting:(NSDictionary *)outputVideoSetting completionHandler:(void (^)(BOOL success))block;

@end
