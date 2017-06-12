//
//  GifDemoViewController.m
//  cgeDemo
//
//  Created by wysaid on 15/12/29.
//  Copyright © 2015年 wysaid. All rights reserved.
//

#import "GifDemoViewController.h"
#import <cge/cgeDynamicImageViewHandler.h>
#import "demoUtils.h"

static const char* const s_functionList[] = {
    "SaveFrames", //0
    "SaveAsGif", //1
    "ViewMode", //2
    "demo 1", //3
    "demo 2", //4
    "demo 3", //5
};

static const int s_functionNum = sizeof(s_functionList) / sizeof(*s_functionList);

@interface GifDemoViewController()

@property (weak, nonatomic) IBOutlet UIButton *quitBtn;

@property (nonatomic) CGEDynamicImageViewHandler* myImageView;
@property (nonatomic) UIScrollView* myScrollView;
@property (nonatomic) GLKView* glkView;

@end

@implementation GifDemoViewController

- (IBAction)quitBtnClicked:(id)sender {
    NSLog(@"Gif Demo Quit...");
    [self dismissViewControllerAnimated:true completion:nil];
    [_myImageView clear];
    _myImageView = nil;
    _glkView = nil;
    _myScrollView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)enterBackground
{
    NSLog(@"enterBackground...");
    [_myImageView stopAnimation];
}

- (void)restoreActive
{
    NSLog(@"restoreActive...");
    [_myImageView startAnimation];
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
    NSLog(@"Screen Rect: %g %g %g %g", rt.origin.x, rt.origin.y, rt.size.width, rt.size.height);
    
    _glkView = [[GLKView alloc] initWithFrame:rt];
    
    _myImageView = [[CGEDynamicImageViewHandler alloc] initWithGLKView:_glkView];
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"gitTest0" withExtension:@"gif"];
    
    [self showGifUrl:url];
    
    [self.view insertSubview:_glkView belowSubview:_quitBtn];
    
    CGRect scrollRT = rt;
    scrollRT.origin.y = scrollRT.size.height - 60;
    scrollRT.size.height = 50;
    _myScrollView = [[UIScrollView alloc] initWithFrame:scrollRT];
    
    CGRect frame = CGRectMake(0, 0, 100, 50);
    
    for(int i = 0; i != s_functionNum; ++i)
    {
        MyButton* btn = [[MyButton alloc] initWithFrame:frame];
        [btn setTitle:[NSString stringWithUTF8String:s_functionList[i]] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [btn.layer setBorderColor:[UIColor redColor].CGColor];
        [btn.layer setBorderWidth:2.0f];
        [btn.layer setCornerRadius:11.0f];
        [btn setIndex:i];
        [btn addTarget:self action:@selector(functionButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [_myScrollView addSubview:btn];
        frame.origin.x += frame.size.width;
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
        frame.origin.x += 70;
    }
    
    _myScrollView.contentSize = CGSizeMake(frame.origin.x, 50);
    
    [self.view addSubview:_myScrollView];
    //    [self.view insertSubview:_myScrollView belowSubview:_galleryBtn];
    [_myImageView setViewDisplayMode:CGEImageViewDisplayModeAspectFit];
    
}

- (void)filterButtonClicked: (MyButton*)sender
{
    NSLog(@"Filter %d Clicked...\n", [sender index]);
    
    const char* config = g_effectConfig[[sender index]];
    [_myImageView setFilterWithConfig:config];
}

- (void)showGifUrl:(NSURL*)url
{
    [_myImageView setGifImage: (__bridge CFURLRef)url];
    [_myImageView startAnimation];
}

- (void)functionButtonClick: (MyButton*)sender
{
    NSLog(@"Function button %d clicked...\n", [sender index]);
    
    switch ([sender index])
    {
        case 0:
        {
            NSDictionary* dict = [_myImageView getResultImages];
            NSArray* arr = [dict objectForKey:@"images"];
            
            [_myImageView.sharedContext asyncProcessingQueue:^{
                
                dispatch_semaphore_t sema = dispatch_semaphore_create(0);
                
                __block int imageIndex = 0;
                
                for(UIImage* img in arr)
                {
                    [DemoUtils saveImage:img completionBlock:^(NSURL *url, NSError *err) {
                        dispatch_semaphore_signal(sema);
                        NSLog(@"image %d saved!\n", imageIndex++);
                    }];
                    
                    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                }
                
                [CGESharedGLContext mainASyncProcessingQueue:^{
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"image saved!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                }];
            }];
            
        }
            break;
        case 1:
        {
            NSURL* url = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/result.gif"]];
            if([_myImageView saveAsGif:url loopCount:0])
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:[NSString stringWithFormat:@"gif image saved to %@!", url] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            }
            else
            {
                NSLog(@"Save as gif failed!");
            }
        }
            break;
        case 2:
        {
            static int modeIndex = 0;
            [_myImageView setViewDisplayMode: (CGEImageViewDisplayMode)modeIndex++];
            modeIndex %= CGEImageViewDisplayModeAspectFit + 1;
        }
            break;
        case 3:
        {
            NSURL *url = [[NSBundle mainBundle] URLForResource:@"gitTest0" withExtension:@"gif"];
            [self showGifUrl:url];
        }
            break;
        case 4:
        {
            NSURL *url = [[NSBundle mainBundle] URLForResource:@"gitTest1" withExtension:@"gif"];
            [self showGifUrl:url];
        }
            break;
        case 5:
        {
            UIImage* img1 = [UIImage imageNamed:@"test.jpg"];
            UIImage* img2 = [UIImage imageNamed:@"test1.jpg"];
            UIImage* img3 = [UIImage imageNamed:@"test2.jpg"];
            NSArray* imgArr = @[img1, img2, img3];
            NSArray* imgDelays = @[@0.2f, @1.5f, @3.5f];
            NSDictionary* gifConfig = @{@"images":imgArr,
                                        @"delayTimes": imgDelays
                                        };
            
            [_myImageView setUIImagesWithConfig:gifConfig startAnimation:YES];
        }
            break;
        default:;
    }
}

@end
