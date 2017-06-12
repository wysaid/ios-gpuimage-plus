//
//  PlayerDemoController.m
//  cgeDemo
//
//  Created by WangYang on 15/8/31.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "PlayerDemoController.h"

#import "demoUtils.h"
#import <cge/cgeUtilFunctions.h>
#import <GLKit/GLKit.h>
#import <cge/cgeVideoPlayerViewHandler.h>
#import <MobileCoreServices/MobileCoreServices.h>

static const char* const s_functionList[] = {
    "mask", //0
    "Pause", //1
    "demo 1", //2
    "demo 2", //3
    "SP_Up", //4
    "SP_Down", //5
    "Reverse", //6
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
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

- (void)enterBackground
{
    NSLog(@"enterBackground...");
    [_videoPlayerHandler pause];
}

- (void)restoreActive
{
    NSLog(@"restoreActive...");
    [_videoPlayerHandler resume];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(restoreActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
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
            [btn setTitle:@"Origin" forState:UIControlStateNormal];
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

    if(!_defaultVideoURL)
    {
        _defaultVideoURL = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"mp4"];
    }

    [self playVideoURL:_defaultVideoURL];
}

#pragma mark - CGEVideoPlayerDelegate

- (void)videoPlayingComplete:(CGEVideoPlayer*)player playItem:(AVPlayerItem *)item
{
    NSLog(@"Play complete, replay...\n");
    [player restart];
}

#pragma mark - CGEVideoPlayerDelegate

- (void)videoResolutionChanged: (CGSize)sz
{
    _videoSize = sz;
    
    if([_videoPlayerHandler isUsingMask])
    {
        [[[_videoPlayerHandler videoPlayer] sharedContext] syncProcessingQueue:^{
            [[[_videoPlayerHandler videoPlayer] sharedContext] makeCurrent];
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

- (void)playTimeUpdated:(CMTime)currentTime
{
    NSLog(@"Play progress: %g\n", CMTimeGetSeconds(currentTime));
}

- (void)playerStatusChanged:(AVPlayerItemStatus)status
{
    NSLog(@"Player status update: %d\n", (int)status);
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
    NSLog(@"glkView size: %g, %g, %g, %g", x, y, w, h);
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

- (void)playVideoURL: (NSURL*)url
{
    [_videoPlayerHandler pause];
    [_videoPlayerHandler startWithURL:url completionHandler:^(NSError* err) {
        if(!err)
        {
            CMTime videoTime = [_videoPlayerHandler videoDuration];
            NSLog(@"video total time: %g 秒\n", CMTimeGetSeconds(videoTime));
            
            [_videoPlayerHandler resume];
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
                [sender setTitle:@"paused" forState:UIControlStateNormal];
            }
            else
            {
                [_videoPlayerHandler resume];
                [sender setTitle:@"playing" forState:UIControlStateNormal];
            }
            break;
            
        case 2:
        {
            NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"mp4"];
            [self playVideoURL:url];
        }
            break;
        case 3:
        {
            NSURL *url = [[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp4"];
            [self playVideoURL:url];
        }
            break;
        case 4:
        {
            [[[_videoPlayerHandler videoPlayer] avPlayer] setRate:2.0];
        }
            break;
        case 5:
        {
            [[[_videoPlayerHandler videoPlayer] avPlayer] setRate:0.5];
        }
            break;
        case 6:
        {
            [[[_videoPlayerHandler videoPlayer] avPlayer] seekToTime:[[[[_videoPlayerHandler videoPlayer] avPlayer] currentItem] duration] toleranceBefore:kCMTimeZero toleranceAfter:kCMTimePositiveInfinity];
            [[[_videoPlayerHandler videoPlayer] avPlayer] setRate:-1.0];
        }
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
