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
    [self ll_seekToTimeInSeconds:time accurate:NO completionHandler:completionHandler];
}

- (void)ll_seekToTimeInSeconds:(float)time accurate:(BOOL)accurate completionHandler:(void (^)(BOOL))completionHandler
{
    if (accurate) {
        [self seekToTime:CMTimeMakeWithSeconds((NSInteger)time, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:completionHandler];
    } else {
        [self seekToTime:CMTimeMakeWithSeconds((NSInteger)time, 1) completionHandler:completionHandler];
    }
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
