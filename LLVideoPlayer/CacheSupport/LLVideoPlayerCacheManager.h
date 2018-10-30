//
//  LLVideoPlayerCacheManager.h
//  LLVideoPlayer
//
//  Created by mario on 2018/10/26.
//

#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerCachePolicy.h"
#import <Foundation/Foundation.h>

@interface LLVideoPlayerCacheManager : NSObject

@property (nonatomic, strong, readonly) NSURLSession *session;

+ (instancetype)defaultManager;

- (LLVideoPlayerCacheFile *)createCacheFileForURL:(NSURL *)url;

- (LLVideoPlayerCacheFile *)getCacheFileForURL:(NSURL *)url;

- (void)releaseCacheFileForURL:(NSURL *)url;

- (void)clearAllCache;
- (void)removeCacheForURL:(NSURL *)url;
- (void)cleanCacheWithPolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

#pragma mark - task
- (NSURLSessionDataTask *)createDataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate;

@end
