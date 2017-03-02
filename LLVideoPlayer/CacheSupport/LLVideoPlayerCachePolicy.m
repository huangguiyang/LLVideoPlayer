//
//  LLVideoPlayerCachePolicy.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCachePolicy.h"

@implementation LLVideoPlayerCachePolicy

+ (instancetype)defaultPolicy
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // default
    }
    return self;
}

@end
