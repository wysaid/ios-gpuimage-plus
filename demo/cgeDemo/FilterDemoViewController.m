//
//  ViewController.m
//  cgeDemo
//
//  Created by wysaid on 15/7/10.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "FilterDemoViewController.h"
#import <cge/cgeUtilFunctions.h>
#import "demoUtils.h"
#import <cge/cgeVideoWriter.h>
#import <cge/cgeImageViewHandler.h>

static const char* const s_functionList[] = {
    "Save", //0
    "FaceTest", //1
    "ViewMode", //2
};

static const int s_functionNum = sizeof(s_functionList) / sizeof(*s_functionList);

@interface FilterDemoViewController ()
@property (weak, nonatomic) IBOutlet UIButton *galleryBtn;
@property (weak, nonatomic) IBOutlet UIButton *quitBtn;
@property (weak, nonatomic) IBOutlet UISlider *intensitySlider;
@property (nonatomic) CGEImageViewHandler* myImageView;
@property (nonatomic) UIScrollView* myScrollView;
@property (nonatomic) GLKView* glkView;
@end

@implementation FilterDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    CGRect rt = [[UIScreen mainScreen] bounds];
    NSLog(@"Screen Rect: %g %g %g %g", rt.origin.x, rt.origin.y, rt.size.width, rt.size.height);
    
    CGRect sliderRT = [_intensitySlider bounds];
    sliderRT.size.width = rt.size.width - 20;
    [_intensitySlider setBounds:sliderRT];
    
    _glkView = [[GLKView alloc] initWithFrame:rt];
    
    UIImage* myImage = [UIImage imageNamed:@"test2.jpg"];
    
    _myImageView = [[CGEImageViewHandler alloc] initWithGLKView:_glkView withImage:myImage];
    
    [self.view insertSubview:_glkView belowSubview:_quitBtn];
//    _myImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    CGRect scrollRT = rt;
    scrollRT.origin.y = scrollRT.size.height - 60;
    scrollRT.size.height = 50;
    _myScrollView = [[UIScrollView alloc] initWithFrame:scrollRT];

    CGRect frame = CGRectMake(0, 0, 85, 50);
    
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
- (IBAction)intensityChanged:(UISlider*)sender {
    float currentIntensity = [sender value] * 3.0f - 1.0f; //[-1, 2]
    [_myImageView setFilterIntensity: currentIntensity];
}

- (IBAction)galleryBtnClicked:(id)sender
{
    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    ipc.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    ipc.delegate = (id)self;
    ipc.allowsEditing = NO; // allowsEditing in 3.1
    [self presentViewController:ipc animated:YES completion:nil];
}
- (IBAction)quitBtnClicked:(id)sender {
    NSLog(@"Filter Demo Quit...");
    [self dismissViewControllerAnimated:true completion:nil];
    [_myImageView clear];
    _myImageView = nil;
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage* myImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    [_myImageView setUIImage:myImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)functionButtonClick: (MyButton*)sender
{
    NSLog(@"Function button %d clicked...\n", [sender index]);
    
    switch ([sender index])
    {
        case 0:
        {
            UIImage* image = [_myImageView resultImage];
            [DemoUtils saveImage:image];
//            [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
            NSLog(@"文件已保存");
        }
            break;
        case 1:
            NSLog(@"Not available for now.");
            break;
        case 2:
        {
            static int modeIndex = 0;
            [_myImageView setViewDisplayMode: (CGEImageViewDisplayMode)modeIndex++];
            modeIndex %= CGEImageViewDisplayModeAspectFit + 1;
        }
        default:
            break;
    }
}

@end
