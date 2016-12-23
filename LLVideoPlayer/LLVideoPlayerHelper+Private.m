//
//  LLVideoPlayerHelper+Private.m
//  LLVideoPlayer
//
//  Created by mario on 2016/12/7.
//  Copyright © 2016 mario. All rights reserved.
//

#import "LLVideoPlayerHelper+Private.h"
#import <UIKit/UIKit.h>

@implementation LLVideoPlayerHelper (Private)

@end

void run_on_ui_thread(dispatch_block_t block)
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
