//
//  LLVideoPlayerCacheTask.h
//  Pods
//
//  Created by mario on 2017/6/23.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCacheFile.h"

@class LLVideoPlayerCacheTask;

@protocol LLVideoPlayerCacheTaskDelegate <NSObject>

@optional
- (void)task:(LLVideoPlayerCacheTask *)task didCompleteWithError:(NSError *)error;

@end

@interface LLVideoPlayerCacheTask : NSObject

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, weak) id<LLVideoPlayerCacheTaskDelegate> delegate;

- (void)resume;
- (void)cancel;
- (BOOL)isCancelled;

@end
