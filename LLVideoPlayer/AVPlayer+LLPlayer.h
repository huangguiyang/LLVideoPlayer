//
//  AVPlayer+LLPlayer.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/29.
//  Copyright © 2016 mario. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVPlayer (LLPlayer)

- (void)ll_seekToTimeInSeconds:(float)time completionHandler:(void (^)(BOOL finished))completionHandler;

- (NSTimeInterval)ll_currentItemDuration;

- (CMTime)ll_currentCMTime;

@end
