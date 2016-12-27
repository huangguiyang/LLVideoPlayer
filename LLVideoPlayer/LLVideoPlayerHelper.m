//
//  LLVideoPlayerHelper.m
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/29.
//  Copyright © 2016 mario. All rights reserved.
//

#import "LLVideoPlayerHelper.h"

@implementation LLVideoPlayerHelper

+ (NSString *)errorCodeToString:(LLVideoPlayerError)errorCode
{
    switch (errorCode) {
        case LLVideoPlayerErrorNone:
            return @"LLVideoPlayerErrorNone";
            
        case LLVideoPlayerErrorStreamNotFound:
            return @"LLVideoPlayerErrorStreamNotFound";
            
        case LLVideoPlayerErrorUnknown:
        default:
            return @"LLVideoPlayerErrorUnknown";
    }
}

+ (NSString *)playerStateToString:(LLVideoPlayerState)state
{
    switch (state) {
        case LLVideoPlayerStateContentLoading:
            return @"LLVideoPlayerStateContentLoading";
            
        case LLVideoPlayerStateContentPlaying:
            return @"LLVideoPlayerStateContentPlaying";
            
        case LLVideoPlayerStateContentPaused:
            return @"LLVideoPlayerStateContentPaused";
            
        case LLVideoPlayerStateError:
            return @"LLVideoPlayerStateError";
            
        case LLVideoPlayerStateDismissed:
            return @"LLVideoPlayerStateDismissed";
            
        case LLVideoPlayerStateUnknown:
        default:
            return @"LLVideoPlayerStateUnknown";
    }
}

+ (NSString *)timeStringFromSecondsValue:(int)seconds
{
    NSString *retVal;
    int hours = seconds / 3600;
    int minutes = (seconds / 60) % 60;
    int secs = seconds % 60;
    if (hours > 0) {
        retVal = [NSString stringWithFormat:@"%01d:%02d:%02d", hours, minutes, secs];
    } else {
        retVal = [NSString stringWithFormat:@"%02d:%02d", minutes, secs];
    }
    return retVal;
}

@end

void ll_run_on_ui_thread(dispatch_block_t block)
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
