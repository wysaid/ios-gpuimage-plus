//
//  SimpleTestCasesViewController.m
//  cgeDemo
//
//  Created by WangYang on 15/11/30.
//  Copyright © 2015年 wysaid. All rights reserved.
//

// 此处为测试使用的无需显示效果的例子。(Here are the test cases that need no display.)

#import "SimpleTestCasesViewController.h"
#import "cgeVideoWriter.h"
#import "demoUtils.h"

#import "cgeVideoFrameRecorder.h"

#define ADD_TEXT(...) [self addText:[NSString stringWithFormat:__VA_ARGS__]];

static NSString* s_functionList[] = {
    @"图片视频测试", //0
    @"视频滤镜测试", //0
};

static const int s_functionNum = sizeof(s_functionList) / sizeof(*s_functionList);

enum DemoTestCase{
    Test_VideoGeneration,
    Test_VideoFileFilter,

};

@interface SimpleTestCasesViewController()<CGEVideoFrameRecorderDelegate>

@property (weak, nonatomic) IBOutlet UIButton *quitBtn;
@property (nonatomic) UIScrollView* myScrollView;
@property (nonatomic) UITextView* myTextView;

@property (nonatomic) CGEVideoFrameRecorder* videoFrameRecorder;

@end

@implementation SimpleTestCasesViewController

- (IBAction)quitBtnClicked:(id)sender {

    NSLog(@"Simple Test Cases Quit...");
    [self dismissViewControllerAnimated:true completion:nil];
    [_videoFrameRecorder clear];
    _videoFrameRecorder = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    int buttonWidth = 150;
    CGRect rt = [[UIScreen mainScreen] bounds];
    CGRect scrollItemFrame = CGRectMake(0, 0, buttonWidth, 50);
    _myScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(rt.size.width - buttonWidth, 20, buttonWidth, rt.size.height - 20)];

    for(int i = 0; i != s_functionNum; ++i)
    {
        MyButton* btn = [[MyButton alloc] initWithFrame:scrollItemFrame];
        [btn setTitle:s_functionList[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [btn.layer setBorderColor:[UIColor redColor].CGColor];
        [btn.layer setBorderWidth:2.0f];
        [btn.layer setCornerRadius:11.0f];
        [btn setIndex:i];
        [btn addTarget:self action:@selector(functionButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [_myScrollView addSubview:btn];
        scrollItemFrame.origin.y += scrollItemFrame.size.height;
    }


    [_myScrollView setContentSize:CGSizeMake(buttonWidth, scrollItemFrame.origin.y)];

    [self.view insertSubview:_myScrollView belowSubview:_quitBtn];

    _myTextView = [[UITextView alloc] initWithFrame:CGRectMake(2, 70, rt.size.width - buttonWidth - 10, rt.size.height - 100)];
    [_myTextView.layer setBorderColor:[UIColor grayColor].CGColor];
    [_myTextView.layer setBorderWidth:2.0f];
    ADD_TEXT(@"Simple Test Cases!\n");
    [self.view insertSubview:_myTextView belowSubview:_quitBtn];
}

- (void)addText:(NSString*)text
{
    if([NSThread isMainThread])
    {
        [_myTextView insertText:text];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_myTextView insertText:text];
        });
    }
}

- (void)functionButtonClick: (MyButton*)sender
{
    if([sender index] < s_functionNum)
    {
        ADD_TEXT(@"Function %@ clicked!\n", s_functionList[[sender index]]);
    }

    switch ([sender index])
    {
        case Test_VideoGeneration:
            ADD_TEXT(@"This test case would generate a movie with several images and an audio file\n");
            [self generateVideoWithImageTestCase];
            break;
        case Test_VideoFileFilter:
            ADD_TEXT(@"This test case would add a filter to a movie and save it to the album\n");
            [self filterVideoFileTestCase];
            break;
        default:
            break;
    }
}

- (void)generateVideoWithImageTestCase
{
    NSArray* arr = @[@"test.jpg", @"test1.jpg", @"test2.jpg"];

    NSURL* video2Save = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/photoVideo.mp4"]];

    NSString* audioPath = [[NSBundle mainBundle] pathForResource:@"yanzhilei" ofType:@"m4a"];
    NSURL* audioURL = [NSURL fileURLWithPath:audioPath];

    id retrieveFunc = ^UIImage *(NSString* imgName) {
        return [UIImage imageNamed:imgName];
    };

    [CGEVideoWriter generateVideoWithImages:video2Save size:CGSizeMake(480, 640) imgSrc:arr imgRetrieveFunc:retrieveFunc audioURL:audioURL quality:AVAssetExportPresetMediumQuality secPerFrame:2.0 completionHandler:^(BOOL success) {

        if(success)
        {
            ADD_TEXT(@"生成视频成功! 已保存至相册!\n");
            [DemoUtils saveVideo:video2Save];
        }
        else
        {
            ADD_TEXT(@"生成视频失败!\n");
        }
    }];
    
}

- (void)videoReadingComplete:(CGEVideoFrameRecorder*)videoFrameRecorder
{
    ADD_TEXT(@"videoReadingComplete...");

    [videoFrameRecorder endRecording:^{
        ADD_TEXT(@"滤镜视频生成完毕!\n");

        [CGEProcessingContext mainSyncProcessingQueue:^{

            [DemoUtils saveVideo:[_videoFrameRecorder outputVideoURL]];
            [_videoFrameRecorder clear];
            _videoFrameRecorder = nil;
        }];
    } withCompressionLevel:2];
}

- (void)videoResolutionChanged: (CGSize)size
{
    ADD_TEXT(@"视频文件分辨率: %g, %g\n", size.width, size.height);
}

- (void)filterVideoFileTestCase
{
    if(_videoFrameRecorder != nil && [_videoFrameRecorder videoLoopRunning])
    {
        [_videoFrameRecorder end];
        [_videoFrameRecorder clear];
        _videoFrameRecorder = nil;
        ADD_TEXT(@"中止视频读取!\n");
        return;
    }

    NSString* srcFilename = rand()%2 ? @"1" : @"test";

    NSURL *url = [[NSBundle mainBundle] URLForResource:srcFilename withExtension:@"mp4"];
    NSURL* video2Save = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/photoVideo.mp4"]];

    NSDictionary* videoConfig = @{
//      @"sourceAsset" : (AVAsset*)sourceAsset     //输入视频Asset(Asset和URL 任选其一)
      @"sourceURL" : url,                          //输入视频URL  (Asset和URL 任选其一)
      @"filterConfig" : [NSString stringWithUTF8String:g_effectConfig[4]],  //滤镜配置 (可不写)
      @"filterIntensity" : @(0.9f),                //滤镜强度 (不写默认 1.0, 范围[0, 1])
      @"blendImage" : [UIImage imageNamed:@"mask1.png"],       //每一帧混合图片 (可不写)
      @"blendMode" : @(CGE_BLEND_OVERLAY),         //混合模式 (当blendImage不存在时无效)
      @"blendIntensity" : @(0.8f)                  //混合强度 (不写默认 1.0, 范围[0, 1])
    };
    
    _videoFrameRecorder = [CGEVideoFrameRecorder generateVideoWithFilter:video2Save size:CGSizeMake(0, 0) withDelegate:self videoConfig:videoConfig];
    
    
    
    
    
//    _videoFrameRecorder = [CGEVideoFrameRecorder generateVideoWithFilter:video2Save size:CGSizeMake(0, 0) sourceURL:url filterConfig:g_effectConfig[4] filterIntensity:1.0f blendImage:nil blendMode:CGE_BLEND_MIX compressLevel:2 withDelegate:self];

//    _videoFrameRecorder = [[CGEVideoFrameRecorder alloc]initWithContext:[CGESharedGLContext globalGLContext]];
//
//    [_videoFrameRecorder setVideoFrameRecorderDelegate:self];
//    [_videoFrameRecorder setFilterWithConfig:g_effectConfig[4]];
//
//    [_videoFrameRecorder setupWithURL:url];
//    [_videoFrameRecorder startRecording:video2Save];
//    [_videoFrameRecorder start];
}

@end


















