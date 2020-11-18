//
//  MainViewController.m
//  cgeDemo
//
//  Created by WangYang on 15/8/31.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "MainViewController.h"
#import "demoUtils.h"
#import "cgeUtilFunctions.h"

@interface MainViewController()
@property (weak, nonatomic) IBOutlet UIButton *filterDemoBtn;
@property (weak, nonatomic) IBOutlet UIButton *cameraDemoBtn;
@property (weak, nonatomic) IBOutlet UIButton *playerDemoBtn;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;


@end

@implementation MainViewController
- (IBAction)filterDemoClicked:(id)sender {
    NSLog(@"filter demo clicked!");
}
- (IBAction)cameraDemoClicked:(id)sender {
    NSLog(@"camera demo clicked!");
}
- (IBAction)playerDemoClicked:(id)sender {
    NSLog(@"player demo clicked!");
}
- (IBAction)testCasesDemoClicked:(id)sender {
    NSLog(@"test cases' demo clicked!");
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"flash screen loaded!");
    cgeSetLoadImageCallback(loadImageCallback, loadImageOKCallback, nil);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView performWithoutAnimation:^{
            
            CGRect rt = [[UIScreen mainScreen] bounds];
            [_scrollView setFrame:rt];
            [_scrollView setScrollEnabled:YES];
            
            NSArray* subviews = [_scrollView subviews];

            int index = 0;
            int buttonWidth = rt.size.width / 2, buttonHeight = 40;

            for(UIView* view in subviews)
            {
                [view setFrame:CGRectMake(20.0, 80 + index * (buttonHeight + 25), buttonWidth, buttonHeight)];
                //                [view setBackgroundColor:[UIColor redColor]];
                [view.layer setShadowColor:[UIColor redColor].CGColor];
                [view.layer setShadowOffset:CGSizeMake(2, 2)];
                [view.layer setBorderWidth:1.5];
                [view.layer setBorderColor:[UIColor blueColor].CGColor];
                [view.layer setShadowOpacity:1.0];
                ++index;
            }
        }];
    });

}


@end
