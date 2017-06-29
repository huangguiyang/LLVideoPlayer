//
//  LLVideoTrack.m
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/29.
//  Copyright © 2016 mario. All rights reserved.
//

#import "LLVideoTrack.h"

@interface LLVideoTrack ()

@property (nonatomic, strong) NSURL *streamURL;

@end

@implementation LLVideoTrack

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> streamURL: %@, totalDuration: %@, lastWatchedDuration: %@, isPlayedToEnd: %@, isCacheComplete: %@",
            NSStringFromClass([self class]), self,
            self.streamURL, self.totalDuration, self.lastWatchedDuration,
            self.isPlayedToEnd ? @"YES" : @"NO",
            self.isCacheComplete ? @"YES" : @"NO"];
}

- (instancetype)init
{
    return [self initWithStreamURL:nil];
}

- (instancetype)initWithStreamURL:(NSURL *)streamURL
{
    self = [super init];
    if (self) {
        self.streamURL = streamURL;
    }
    return self;
}

@end
