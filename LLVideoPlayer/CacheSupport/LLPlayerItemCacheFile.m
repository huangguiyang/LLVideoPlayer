//
//  LLPlayerItemCacheFile.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLPlayerItemCacheFile.h"

#define kIndexFileExtension @".idx!"

@implementation LLPlayerItemCacheFile

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath
{
    return [[self alloc] initWithFilePath:filePath];
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        NSString *cacheFilePath = [filePath copy];
        NSString *indexFilePath = [NSString stringWithFormat:@"%@%@", filePath, kIndexFileExtension];
        
        BOOL cacheFileExist = [[NSFileManager defaultManager] fileExistsAtPath:cacheFilePath];
        BOOL indexFileExist = [[NSFileManager defaultManager] fileExistsAtPath:indexFilePath];
        
        BOOL fileExist = cacheFileExist && indexFileExist;
        if (NO == fileExist) {
            NSString *directory = [cacheFilePath stringByDeletingLastPathComponent];
            if (NO == [[NSFileManager defaultManager] fileExistsAtPath:directory]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
            }
            
            fileExist = [[NSFileManager defaultManager] createFileAtPath:cacheFilePath contents:nil attributes:nil] && [[NSFileManager defaultManager] createFileAtPath:indexFilePath contents:nil attributes:nil];
        }
        
        if (NO == fileExist) {
            return nil;
        }
    }
    return self;
}

- (BOOL)saveData:(NSData *)data offset:(NSInteger)offset flags:(NSInteger)flags
{
    return NO;
}

- (NSData *)dataWithRange:(NSRange)range
{
    return nil;
}

@end
