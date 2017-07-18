//
//  LLVideoPlayerCacheFile+CachePolicy.m
//  Pods
//
//  Created by mario on 2017/6/19.
//
//

#import "LLVideoPlayerCacheFile+CachePolicy.h"
#import "LLVideoPlayerInternal.h"

#define kMinFreeSpaceLimit (1ULL << 30)

static uint64_t diskFreeCapacity(void)
{
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) {
        return -1;
    }
    int64_t space = [attrs[NSFileSystemFreeSize] longLongValue];
    if (space < 0) {
        space = -1;
    }
    return space;
}

static uint64_t diskCapacity(void)
{
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) {
        return -1;
    }
    int64_t space = [attrs[NSFileSystemSize] longLongValue];
    if (space < 0) {
        space = -1;
    }
    return space;
}

@implementation LLVideoPlayerCacheFile (CachePolicy)

+ (void)removeCacheAtPath:(NSString *)path
{
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSString *index = [path stringByAppendingString:[self indexFileExtension]];
    [[NSFileManager defaultManager] removeItemAtPath:index error:nil];
    LLLog(@"cache deleted: %@, %@", path, index);
}

+ (void)checkCacheDirectoryWithCachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    NSString *directory = [[self class] cacheDirectory];
    NSError *error;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:&error];
    if (error) {
        LLLog(@"[ERR] can't get contents of directory: %@, error: %@", directory, error);
        return;
    }

    if (nil == cachePolicy) {
        cachePolicy = [LLVideoPlayerCachePolicy defaultPolicy];
    }
    
    NSUInteger totalSize = 0;
    NSDate *now = [NSDate date];
    NSMutableArray *paths = [NSMutableArray array];
    
    for (NSString *name in contents) {
        if ([name hasSuffix:[[self class] indexFileExtension]]) {
            continue;
        }
        
        NSString *path = [directory stringByAppendingPathComponent:name];
        error = nil;
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        if (error) {
            LLLog(@"[ERR] can't get attributes of file: %@, error: %@", path, error);
            continue;
        }
        if (NO == [[attr fileType] isEqualToString:NSFileTypeRegular]) {
            continue;
        }
        
        NSDate *date = [attr fileCreationDate];
        NSInteger hours = [now timeIntervalSinceDate:date] / 3600;
        if (hours >= cachePolicy.outdatedHours) {
            [[self class] removeCacheAtPath:path];
            continue;
        }
        
        [paths addObject:path];
        totalSize += [attr fileSize];
    }
    
    const uint64_t minFreeSpaceLimit = kMinFreeSpaceLimit;
    int64_t diskSpaceFreeSize = diskFreeCapacity();
    
    if (totalSize < cachePolicy.diskCapacity) {
        if (diskSpaceFreeSize >= minFreeSpaceLimit) {
            return;
        }
    }
    
    [paths sortUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        NSDictionary *attr1 = [[NSFileManager defaultManager] attributesOfItemAtPath:obj1 error:nil];
        NSDictionary *attr2 = [[NSFileManager defaultManager] attributesOfItemAtPath:obj2 error:nil];
        NSDate *date1 = [attr1 fileCreationDate];
        NSDate *date2 = [attr2 fileCreationDate];
        return [date1 compare:date2];
    }];
    
    while (paths.count > 0 && (totalSize >= cachePolicy.diskCapacity || diskSpaceFreeSize < minFreeSpaceLimit)) {
        NSString *path = [paths firstObject];
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        [[self class] removeCacheAtPath:path];
        totalSize -= [attr fileSize];
        diskSpaceFreeSize += [attr fileSize];
        [paths removeObject:path];
    }
}

@end
