//
//  LLVideoTrack.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/29.
//  Copyright © 2016 mario. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LLVideoTrack : NSObject

- (instancetype)initWithStreamURL:(NSURL *)streamURL;

@property (nonatomic, assign) BOOL isPlayedToEnd;
@property (nonatomic, strong) NSNumber *totalDuration;
@property (nonatomic, strong) NSNumber *lastWatchedDuration;
@property (nonatomic, strong, readonly) NSURL *streamURL;
@property (nonatomic, assign) BOOL isCacheComplete;

@end
