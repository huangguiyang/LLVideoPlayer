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

static NSString *kIndexFileExtension = @".idx";

@interface LLVideoPlayerCacheFile ()

@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) LLVideoPlayerCachePolicy *cachePolicy;
@property (nonatomic, strong) NSString *indexFilePath;
@property (nonatomic, strong) NSMutableDictionary *indexInfo;
@property (nonatomic, strong) NSMutableArray<NSValue *> *ranges;

@end

@implementation LLVideoPlayerCacheFile

+ (NSString *)cacheDirectory
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cache stringByAppendingPathComponent:@"LLVideoPlayer"];
}

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
        self.cachePolicy = cachePolicy;
        self.cacheFilePath = filePath;
        self.indexFilePath = [NSString stringWithFormat:@"%@%@", filePath, kIndexFileExtension];
        
        NSString *dir = [filePath stringByDeletingLastPathComponent];
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:dir] &&
            NO == [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                            withIntermediateDirectories:YES attributes:nil error:nil]) {
            LLLog(@"cannot create directory: %@", dir);
            return nil;
        }
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.indexFilePath]) {
            // load index data
            [self loadIndexFile];
        }
        
        LLLog(@"[CacheSupport] cache file path: %@", filePath);
    }
    return self;
}

#pragma mark - Private

- (void)loadIndexFile
{
    
}

@end
