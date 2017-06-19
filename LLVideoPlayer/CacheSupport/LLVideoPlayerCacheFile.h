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

#pragma mark - Read/Write

- (NSData *)dataWithRange:(NSRange)range error:(NSError **)error;
- (BOOL)writeData:(NSData *)data atOffset:(NSInteger)offset;

- (void)receivedResponse:(NSHTTPURLResponse *)response forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest;
- (void)tryResponseForLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest withRange:(NSRange)requestRange;

#pragma mark - Property
@property (nonatomic, strong, readonly) NSDictionary *allHeaderFields;
@property (nonatomic, strong, readonly) NSMutableArray<NSValue *> *ranges;
@property (nonatomic, assign, readonly) NSInteger fileLength;

@end
