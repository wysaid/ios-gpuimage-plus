//
//  PlayerDemoController.m
//  cgeDemo
//
//  Created by WangYang on 15/8/31.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "PlayerDemoController.h"

#import "demoUtils.h"
#import "cgeUtilFunctions.h"
#import <GLKit/GLKit.h>
#import "cgeVideoPlayerViewHandler.h"
#import <MobileCoreServices/MobileCoreServices.h>

static const char* const s_functionList[] = {
    "mask", //0
    "暂停", //1
    "demo 1", //2
    "demo 2", //3
};

static const int s_functionNum = sizeof(s_functionList) / sizeof(*s_functionList);

////////////////////////////////////

@interface PlayerDemoController() <CGEVideoPlayerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *quitBtn;

@property (nonatomic) UIScrollView* myScrollView;
@property (nonatomic) GLKView* glkView;
@property (nonatomic) int currentFilterIndex;

@property CGEVideoPlayerViewHandler* videoPlayerHandler;

@property (nonatomic) CGSize videoSize;
@property (nonatomic) CGSize maskSize;

@end

@implementation PlayerDemoController
- (IBAction)quitBtnClicked:(id)sender {
    
    NSLog(@"Player Demo Quit...");
    [self dismissViewControllerAnimated:true completion:nil];
    [_videoPlayerHandler clear];
    _videoPlayerHandler = nil;
    [CGESharedGLContext clearGlobalGLContext];
}
- (IBAction)choosVideoBtnClicked:(id)sender {
    [_videoPlayerHandler pause];
    
    UIImagePickerController *videoPicker = [[UIImagePickerController alloc] init];
    videoPicker.delegate = self;
    videoPicker.modalPresentationStyle = UIModalPresentationCurrentContext;
    videoPicker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    videoPicker.mediaTypes = @[(NSString*)kUTTypeMovie];
    
    [self presentViewController:videoPicker animated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cgeSetLoadImageCallback(loadImageCallback, loadImageOKCallback, nil);
    
    CGRect rt = [[UIScreen mainScreen] bounds];
    
    _glkView = [[GLKView alloc] initWithFrame:rt];
    
    _videoPlayerHandler = [[CGEVideoPlayerViewHandler alloc] initWithGLKView:_glkView];
    
    [[_videoPlayerHandler videoPlayer] setPlayerDelegate:self];
    [self.view insertSubview:_glkView belowSubview:_quitBtn];
    
    CGRect scrollRT = rt;
    scrollRT.origin.y = scrollRT.size.height - 60;
    scrollRT.size.height = 50;
    _myScrollView = [[UIScrollView alloc] initWithFrame:scrollRT];
    
    CGSize frameSize = CGSizeMake(85, 50);
    CGRect frame = CGRectMake(0, 0, frameSize.width, frameSize.height);

    for(int i = 0; i != s_functionNum; ++i)
    {
        MyButton* btn = [[MyButton alloc] initWithFrame: frame];
        [btn setTitle:[NSString stringWithUTF8String:s_functionList[i]] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [btn.layer setBorderColor:[UIColor blueColor].CGColor];
        [btn.layer setBorderWidth:1.5f];
        [btn.layer setCornerRadius:10.0f];
        [btn setIndex:i];
        [btn addTarget:self action:@selector(functionButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [_myScrollView addSubview:btn];
        frame.origin.x += frameSize.width;
    }
    
    frame.size.width = 70;
    
    for(int i = 0; i != g_configNum; ++i)
    {
        MyButton* btn = [[MyButton alloc] initWithFrame:frame];
        
        if(i == 0)
            [btn setTitle:@"原图" forState:UIControlStateNormal];
        else
            [btn setTitle:[NSString stringWithFormat:@"filter%d", i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [btn.layer setBorderColor:[UIColor blueColor].CGColor];
        [btn.layer setBorderWidth:1.5f];
        [btn.layer setCornerRadius:10.0f];
        [btn setIndex:i];
        [btn addTarget:self action:@selector(filterButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [_myScrollView addSubview:btn];
        frame.origin.x += frameSize.width;
    }
    
    [_myScrollView setContentSize:CGSizeMake(frame.origin.x, frameSize.height)];
    
    [self.view addSubview:_myScrollView];
    
    _videoSize = CGSizeMake(640, 480);
    [self playDemoVideo];
}

#pragma mark - CGEVideoPlayerDelegate

- (void)videoPlayingComplete:(CGEVideoPlayer*)player playItem:(AVPlayerItem *)item
{
    NSLog(@"播放结束， 重新开始播放...\n");
    [player restart];
}

#pragma mark - CGEVideoPlayerDelegate

- (void)videoResolutionChanged: (CGSize)sz
{
    _videoSize = sz;
    
    if([_videoPlayerHandler isUsingMask])
    {
        [[[_videoPlayerHandler videoPlayer] sharedContext] syncProcessingQueue:^{
            [[_videoPlayerHandler videoPlayer] setMaskTextureRatio:_maskSize.width / _maskSize.height];
        }];
        
        [CGEProcessingContext mainSyncProcessingQueue:^{
            [self viewFitMaskSize:_maskSize];
        }];
        return;
    }
    
    [CGEProcessingContext mainSyncProcessingQueue:^{
        
        CGRect rt = [[UIScreen mainScreen] bounds];
        
        CGFloat x, y, w = sz.width, h = sz.height;
        
        CGFloat scaling = MIN(rt.size.width / (float)w, rt.size.height / (float)h);
        
        w *= scaling;
        h *= scaling;
        
        x = (rt.size.width - w) / 2.0;
        y = (rt.size.height - h) / 2.0;
        
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.5];
        [_glkView setFrame:CGRectMake(x, y, w, h)];
        [UIView commitAnimations];
        NSLog(@"glkView 尺寸: %g, %g, %g, %g", x, y, w, h);
    }];
}

- (void)viewFitMaskSize:(CGSize)sz
{
    CGRect rt = [[UIScreen mainScreen] bounds];
    CGFloat x, y, w = sz.width, h = sz.height;
    float scaling = MIN(rt.size.width / (float)w, rt.size.height / (float)h);
    
    w *= scaling;
    h *= scaling;
    
    x = (rt.size.width - w) / 2.0;
    y = (rt.size.height - h) / 2.0;
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    [_glkView setFrame:CGRectMake(x, y, w, h)];
    [UIView commitAnimations];
    NSLog(@"glkView 尺寸: %g, %g, %g, %g", x, y, w, h);
}

- (void)setMask
{
    if([_videoPlayerHandler isUsingMask])
    {
        [_videoPlayerHandler setMaskUIImage:nil];
        _maskSize = _videoSize;
    }
    else
    {
        UIImage* img = [UIImage imageNamed:@"mask1.png"];
        _maskSize = img.size;
        [_videoPlayerHandler setMaskUIImage:img];
    }
    
    [self viewFitMaskSize:_maskSize];
}

- (void)playDemoVideo
{
    NSURL *sampleURL = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"mp4"];
    [self playVideoURL:sampleURL];
}

- (void)playVideoURL: (NSURL*)url
{
    [_videoPlayerHandler pause];
    [_videoPlayerHandler startWithURL:url completionHandler:^(NSError* err) {
        if(!err)
        {
            [[[_videoPlayerHandler videoPlayer] avPlayer] play];
        }
        else
        {
            NSLog(@"play video failed: %@", err);
        }
    }];
}

- (void)functionButtonClick: (MyButton*)sender
{
    NSLog(@"Function button %d clicked...\n", [sender index]);
    
    switch ([sender index])
    {
        case 0:
            [self setMask];
            break;
        case 1:
            if([_videoPlayerHandler isPlaying])
            {
                [_videoPlayerHandler pause];
                [sender setTitle:@"已暂停" forState:UIControlStateNormal];
            }
            else
            {
                [_videoPlayerHandler resume];
                [sender setTitle:@"播放中" forState:UIControlStateNormal];
            }
            break;
            
        case 2:
            [self playDemoVideo];
            break;
        case 3:
        {
            [_videoPlayerHandler pause];
            NSURL *url = [[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp4"];
            [self playVideoURL:url];
        }
            break;
        default:
            break;
    }
}

- (void)filterButtonClicked: (MyButton*)sender
{
    _currentFilterIndex = [sender index];
    NSLog(@"Filter %d Clicked...\n", _currentFilterIndex);
    
    const char* config = g_effectConfig[_currentFilterIndex];
    [_videoPlayerHandler setFilterWithConfig:config];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [self playVideoURL:info[UIImagePickerControllerReferenceURL]];
    
    picker.delegate = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // Make sure our playback is resumed from any interruption.
    [_videoPlayerHandler resume];
    
    picker.delegate = nil;
}

@end
