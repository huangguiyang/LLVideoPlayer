//
//  LLVideoPlayerCacheTask.h
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCacheFile.h"

@class LLVideoPlayerCacheTask;

@protocol LLVideoPlayerCacheTaskDelegate <NSObject>

- (void)taskDidFinish:(LLVideoPlayerCacheTask *)task;
- (void)task:(LLVideoPlayerCacheTask *)task didFailWithError:(NSError *)error;

@end

@interface LLVideoPlayerCacheTask : NSObject

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, weak) id<LLVideoPlayerCacheTaskDelegate> delegate;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;

- (void)resume;
- (void)cancel;
- (BOOL)isCancelled;

@end
