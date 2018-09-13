//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LLVideoPlayerCacheFile : NSObject

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath;

- (instancetype)initWithFilePath:(NSString *)filePath;

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

@end
