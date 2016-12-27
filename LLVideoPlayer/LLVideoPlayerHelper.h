//
//  LLVideoPlayerHelper.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/29.
//  Copyright © 2016 mario. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LLVideoPlayerDefines.h"

@interface LLVideoPlayerHelper : NSObject

+ (NSString *)errorCodeToString:(LLVideoPlayerError)errorCode;

+ (NSString *)playerStateToString:(LLVideoPlayerState)state;

+ (NSString *)timeStringFromSecondsValue:(int)seconds;

@end


void ll_run_on_ui_thread(dispatch_block_t);
