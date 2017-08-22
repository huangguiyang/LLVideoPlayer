//
//  LLVideoPlayerCacheOperation.h
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCacheFile.h"

@class LLVideoPlayerCacheOperation;
@protocol LLVideoPlayerCacheOperationDelegate <NSObject>

- (void)operationDidFinish:(LLVideoPlayerCacheOperation *)operation;
- (void)operation:(LLVideoPlayerCacheOperation *)operation didFailWithError:(NSError *)error;

@end

@interface LLVideoPlayerCacheOperation : NSObject

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

+ (instancetype)operationWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                  cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, strong, readonly) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, weak) id<LLVideoPlayerCacheOperationDelegate> delegate;

- (void)resume;
- (void)cancel;

@end
