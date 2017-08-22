//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCachePolicy.h"

@interface LLVideoPlayerCacheFile : NSObject

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

- (instancetype)initWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

+ (NSString *)cacheDirectory;
+ (NSString *)indexFileExtension;

#pragma mark - Read/Write

- (NSData *)dataWithRange:(NSRange)range error:(NSError **)error;
- (void)writeData:(NSData *)data atOffset:(NSInteger)offset;

- (void)receivedResponse:(NSURLResponse *)response forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest;
- (void)tryResponseForLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest withRange:(NSRange)requestRange;

- (void)synchronize;
- (void)clear;

- (BOOL)isComplete;

#pragma mark - Property
- (NSArray<NSValue *> *)cachedRanges;
@property (nonatomic, assign, readonly) NSInteger fileLength;

@property (nonatomic, strong, readonly) NSString *cacheFilePath;
@property (nonatomic, strong, readonly) LLVideoPlayerCachePolicy *cachePolicy;

@end
