//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LLCacheFileSaveFlags) {
    LLCacheFileSaveFlagsNone,
    LLCacheFileSaveFlagsSyncIndex,
};

@interface LLVideoPlayerCacheFile : NSObject

@property (nonatomic, strong) NSDictionary *responseHeaders;
@property (nonatomic, assign, readonly) NSUInteger fileLength;

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath;

- (instancetype)initWithFilePath:(NSString *)filePath;

- (BOOL)saveData:(NSData *)data offset:(NSUInteger)offset flags:(LLCacheFileSaveFlags)flags;

- (NSData *)dataWithRange:(NSRange)range;

- (NSRange)firstNotCachedRangeFromPosition:(NSUInteger)position;

- (void)removeCache;

- (BOOL)setResponse:(NSHTTPURLResponse *)response;

- (NSUInteger)maxCachedLength;

@end
