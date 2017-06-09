//
//  LLVideoPlayerCacheTask.h
//  Pods
//
//  Created by mario on 2017/6/9.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCacheFile.h"

@interface LLVideoPlayerCacheTask : NSObject

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile
                       userInfo:(NSDictionary *)userInfo;

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile
                       userInfo:(NSDictionary *)userInfo;

@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, copy) void (^completionBlock)(LLVideoPlayerCacheTask *task, NSError *error);

- (void)resume;
- (void)cancel;
- (BOOL)isCancelled;

@end
