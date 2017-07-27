//
//  LLVideoPlayerCacheHelper.m
//  Pods
//
//  Created by mario on 2017/6/28.
//
//

#import "LLVideoPlayerCacheHelper.h"
#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerDownloader.h"

@implementation LLVideoPlayerCacheHelper

+ (void)clearAllCache
{
    NSString *dir;
    
    dir = [LLVideoPlayerCacheFile cacheDirectory];
    [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
    
    dir = [LLVideoPlayerDownloader cacheDirectory];
    [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
}

+ (void)preloadWithURL:(NSURL *)url
{
    [[LLVideoPlayerDownloader defaultDownloader] preloadWithURL:url];
}

+ (void)cancelWithURL:(NSURL *)url
{
    [[LLVideoPlayerDownloader defaultDownloader] cancelWithURL:url];
}

+ (void)cancelAllPreloads
{
    [[LLVideoPlayerDownloader defaultDownloader] cancelAllPreloads];
}

@end
