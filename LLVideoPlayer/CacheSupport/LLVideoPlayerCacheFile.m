//
//  LLVideoPlayerCacheFile.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "LLVideoPlayerInternal.h"
#include <pthread.h>

@interface LLVideoPlayerCacheFile ()

@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) LLVideoPlayerCachePolicy *cachePolicy;

@end

@implementation LLVideoPlayerCacheFile

- (void)dealloc
{
}

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    return [[self alloc] initWithFilePath:filePath cachePolicy:cachePolicy];
}

- (instancetype)initWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    self = [super init];
    if (self) {
    }
    return self;
}

+ (NSString *)cacheDirectory
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cache stringByAppendingPathComponent:@"LLVideoPlayer"];
}

#pragma mark - Private

@end
