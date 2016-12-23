//
//  AVPlayer+LLPlayer.m
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/29.
//  Copyright © 2016 mario. All rights reserved.
//

#import "AVPlayer+LLPlayer.h"

@implementation AVPlayer (LLPlayer)

- (void)ll_seekToTimeInSeconds:(float)time completionHandler:(void (^)(BOOL))completionHandler
{
    [self seekToTime:CMTimeMakeWithSeconds(time, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:completionHandler];
}

- (NSTimeInterval)ll_currentItemDuration
{
    return CMTimeGetSeconds([self.currentItem duration]);
}

- (CMTime)ll_currentCMTime
{
    return [self currentTime];
}

@end
