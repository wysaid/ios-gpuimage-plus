//
//  ViewController.m
//  cgeDemo
//
//  Created by wysaid on 15/7/10.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "FilterDemoViewController.h"
#import "cgeUtilFunctions.h"
#import "demoUtils.h"

@interface FilterDemoViewController ()
@property (weak, nonatomic) IBOutlet UIButton *galleryBtn;
@property (weak, nonatomic) IBOutlet UIButton *quitBtn;
@property (nonatomic) UIImage* myImage;
@property (nonatomic) UIImageView* myImageView;
@property (nonatomic) UIScrollView* myScrollView;
@end

@implementation FilterDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    cgeSetLoadImageCallback(loadImageCallback, loadImageOKCallback, nil);
    
    CGRect rt = [[UIScreen mainScreen] bounds];
    NSLog(@"Screen Rect: %g %g %g %g", rt.origin.x, rt.origin.y, rt.size.width, rt.size.height);
    _myImageView = [[UIImageView alloc] initWithFrame:rt];
    _myImage = [UIImage imageNamed:@"1.jpg"];
    [_myImageView setImage:_myImage];
    [self.view insertSubview:_myImageView belowSubview:_galleryBtn];
    _myImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    CGRect scrollRT = rt;
    scrollRT.origin.y = scrollRT.size.height - 60;
    scrollRT.size.height = 50;
    _myScrollView = [[UIScrollView alloc] initWithFrame:scrollRT];

    CGRect frame = CGRectMake(0, 0, 70, 50);
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
        frame.origin.x += 70;
    }
    
    _myScrollView.contentSize = CGSizeMake(frame.origin.x, 50);
    
    [self.view addSubview:_myScrollView];
//    [self.view insertSubview:_myScrollView belowSubview:_galleryBtn];
    CGRect btnRect = [_quitBtn bounds];
    btnRect.origin.x = rt.size.width - btnRect.size.width - 10;
    [_quitBtn setFrame:btnRect];
}

- (void)filterButtonClicked: (MyButton*)sender
{
    NSLog(@"Filter %d Clicked...\n", [sender index]);
    
    const char* config = g_effectConfig[[sender index]];
    [self filterImage:config intensity:1.0f];
}

- (void) filterImage: (const char*)config intensity:(float)intensity
{
    if(_myImage == nil)
        return;
    
    UIImage* newImage = cgeFilterUIImage_MultipleEffects(_myImage, config, intensity, nil);
    
    [_myImageView setImage:newImage];
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
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    _myImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    [_myImageView setImage:_myImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
