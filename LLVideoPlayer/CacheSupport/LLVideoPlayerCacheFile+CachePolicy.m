//
//  LLVideoPlayerCacheFile+CachePolicy.m
//  Pods
//
//  Created by mario on 2017/6/19.
//
//

#import "LLVideoPlayerCacheFile+CachePolicy.h"
#import "LLVideoPlayerInternal.h"

@implementation LLVideoPlayerCacheFile (CachePolicy)

+ (int64_t)diskSpaceFree
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

+ (int64_t)diskSpace
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

+ (void)removeCacheAtPath:(NSString *)path
{
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSString *index = [path stringByAppendingPathComponent:[self indexFileExtension]];
    [[NSFileManager defaultManager] removeItemAtPath:index error:nil];
    LLLog(@"cache deleted: %@", path);
}

- (void)checkCacheDirectory
{
    NSString *directory = [[self class] cacheDirectory];
    NSError *error;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:&error];
    if (error) {
        LLLog(@"[ERR] can't get contents of directory: %@, error: %@", directory, error);
        return;
    }
    
    NSString *cacheFilePath = self.cacheFilePath;
    LLVideoPlayerCachePolicy *cachePolicy = self.cachePolicy;
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
        if ([path isEqualToString:cacheFilePath]) {
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
    
    CGFloat currentDiskAvailableRate = cachePolicy.diskAvailableRate;
    
    if (totalSize < cachePolicy.diskCapacity) {
        int64_t diskSpaceSize = [[self class] diskSpace];
        int64_t diskSpaceFreeSize = [[self class] diskSpaceFree];
        if (-1 != diskSpaceSize && -1 != diskSpaceFreeSize) {
            currentDiskAvailableRate = (CGFloat)diskSpaceFreeSize / (CGFloat)diskSpaceSize;
        }
        
        if (currentDiskAvailableRate >= cachePolicy.diskAvailableRate) {
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
    
    while (paths.count > 0 && (totalSize  >= cachePolicy.diskCapacity || currentDiskAvailableRate < cachePolicy.diskAvailableRate)) {
        NSString *path = [paths firstObject];
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        [[self class] removeCacheAtPath:path];
        totalSize -= [attr fileSize];
        [paths removeObject:path];
    }
}

@end
