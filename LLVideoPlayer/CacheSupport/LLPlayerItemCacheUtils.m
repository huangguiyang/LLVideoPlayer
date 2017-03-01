//
//  LLPlayerItemCacheUtils.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLPlayerItemCacheUtils.h"

const NSRange LLInvalidRange = { NSNotFound, 0 };

@implementation LLPlayerItemCacheUtils

+ (NSString *)cacheDirectoryPath
{
    NSString *cache = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [cache stringByAppendingPathComponent:@"com.ll.vplayer"];
    return dir;
}

@end
