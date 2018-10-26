//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN NSString * const kLLVideoCacheFileExtensionIndex;
FOUNDATION_EXTERN NSString * const kLLVideoCacheFileExtensionPreload;
FOUNDATION_EXTERN NSString * const kLLVideoCacheFileExtensionPreloding;

@interface LLVideoPlayerCacheFile : NSObject

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath;

- (instancetype)initWithFilePath:(NSString *)filePath;

#pragma mark - Read/Write

- (NSData *)dataWithRange:(NSRange)range error:(NSError **)error;
- (void)writeData:(NSData *)data atOffset:(NSInteger)offset;
- (void)receiveResponse:(NSURLResponse *)response;

- (NSURLResponse *)constructURLResponseForURL:(NSURL *)url andRange:(NSRange)range;
- (void)enumerateRangesWithRequestRange:(NSRange)requestRange usingBlock:(void (^)(NSRange range, BOOL cached))block;

- (void)synchronize;

- (BOOL)isComplete;

- (NSArray *)cachedRanges;
+ (NSString *)cacheDirectory;

#pragma mark - Property

@property (nonatomic, assign, readonly) NSUInteger fileLength;
@property (nonatomic, strong, readonly) NSString *cacheFilePath;

@end
