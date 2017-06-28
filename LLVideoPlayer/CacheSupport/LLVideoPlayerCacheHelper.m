//
//  LLVideoPlayerCacheHelper.m
//  Pods
//
//  Created by mario on 2017/6/28.
//
//

#import "LLVideoPlayerCacheHelper.h"
#import "LLVideoPlayerCacheFile.h"

@implementation LLVideoPlayerCacheHelper

+ (void)clearAllCache
{
    NSString *dir = [LLVideoPlayerCacheFile cacheDirectory];
    [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
}

@end
