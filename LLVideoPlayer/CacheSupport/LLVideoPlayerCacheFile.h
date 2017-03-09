//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import "LLVideoPlayerCachePolicy.h"

@interface LLVideoPlayerCacheFile : NSObject

@property (nonatomic, strong) NSDictionary *responseHeaders;
@property (nonatomic, assign, readonly) NSUInteger fileLength;

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

- (instancetype)initWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

- (BOOL)saveData:(NSData *)data atOffset:(NSUInteger)offset synchronize:(BOOL)synchronize;

- (NSData *)dataWithRange:(NSRange)range;

- (NSRange)firstNotCachedRangeFromPosition:(NSUInteger)position;

- (BOOL)setResponse:(NSHTTPURLResponse *)response;

- (NSUInteger)maxCachedLength;

- (BOOL)synchronize;

- (BOOL)isCompleted;

+ (NSString *)cacheDirectory;

@end
