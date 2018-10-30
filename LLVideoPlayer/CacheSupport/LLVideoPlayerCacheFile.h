//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN NSString * const kLLVideoCacheFileExtensionIndex;

@interface LLVideoPlayerCacheFile : NSObject

- (instancetype)initWithURL:(NSURL *)url;

#pragma mark - Read/Write

- (NSData *)dataWithRange:(NSRange)range;
- (void)writeData:(NSData *)data atOffset:(NSUInteger)offset;
- (void)receiveResponse:(NSURLResponse *)response;

- (NSURLResponse *)constructURLResponseForURL:(NSURL *)url andRange:(NSRange)range;
- (void)enumerateRangesWithRequestRange:(NSRange)requestRange usingBlock:(void (^)(NSRange range, BOOL cached))block;

- (void)synchronize;

- (BOOL)isComplete;

+ (NSString *)cacheDirectory;
+ (NSString *)cacheFilePathWithURL:(NSURL *)url;

#pragma mark - Property

@property (nonatomic, assign, readonly) NSUInteger fileLength;
@property (nonatomic, strong, readonly) NSString *cacheFilePath;

@end
