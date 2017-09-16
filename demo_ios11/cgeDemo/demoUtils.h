//
//  demoUtils.h
//  cgeDemo
//
//  Created by WangYang on 15/9/6.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

UIImage* loadImageCallback(const char* name, void* arg);

void loadImageOKCallback(UIImage* img, void* arg);

extern const char* g_effectConfig[];
extern int g_configNum;

@interface DemoUtils : NSObject

+ (void)saveVideo :(NSURL*)videoURL;
+ (void)saveImage :(UIImage*)image;
+ (void)saveImage :(UIImage*)image completionBlock:(void (^)(NSURL*, NSError*))block;

@end


@interface MyButton : UIButton
@property (nonatomic) int index;
@end
