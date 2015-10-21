//
//  MainViewController.m
//  cgeDemo
//
//  Created by WangYang on 15/8/31.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "MainViewController.h"


@interface MainViewController()
@property (weak, nonatomic) IBOutlet UIButton *filterDemoBtn;
@property (weak, nonatomic) IBOutlet UIButton *cameraDemoBtn;
@property (weak, nonatomic) IBOutlet UIButton *playerDemoBtn;


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

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"flash screen loaded!");
}


@end