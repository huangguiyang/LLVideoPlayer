//
//  LLVideoPlayerCacheUtils.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheUtils.h"

const NSRange LLInvalidRange = { NSNotFound, 0 };

@implementation LLVideoPlayerCacheUtils

+ (NSString *)cacheDirectoryPath
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [cache stringByAppendingPathComponent:@"com.ll.vplayer"];
    return dir;
}

@end
