//
//  demoUtils.m
//  cgeDemo
//
//  Created by WangYang on 15/9/6.
//  Copyright (c) 2015年 wysaid. All rights reserved.
//

#import "demoUtils.h"
#import "cgeSharedGLContext.h"
#import <AssetsLibrary/ALAssetsLibrary.h>

const char* g_effectConfig[] = {
    nil,
};

int g_configNum = sizeof(g_effectConfig) / sizeof(*g_effectConfig);

UIImage* loadImageCallback(const char* name, void* arg)
{
    NSString* filename = [NSString stringWithUTF8String:name];
    return [UIImage imageNamed:filename];
}

void loadImageOKCallback(UIImage* img, void* arg)
{
    
}


@implementation DemoUtils

+ (void)saveVideo :(NSURL*)videoURL
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:videoURL])
    {
        [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{

                 if (error)
                 {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                 }
                 else
                 {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                 }
             });
         }];
    }
    else
    {
        [CGEProcessingContext mainSyncProcessingQueue:^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"File format is not compatibale with album!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }];
    }
}

+ (void)saveImage:(UIImage *)image
{
    [DemoUtils saveImage:image completionBlock:nil];
}

+ (void)saveImage:(UIImage *)image completionBlock:(void (^)(NSURL *, NSError *))block
{
    [CGEProcessingContext mainSyncProcessingQueue:^{
        
        if(image != nil)
        {
            [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:block];
        }
    }];
}

@end

@implementation MyButton


@end

