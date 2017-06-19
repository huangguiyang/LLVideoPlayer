//
//  LLVideoPlayerCacheOperation.h
//  Pods
//
//  Created by mario on 2017/6/8.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCacheFile.h"

@interface LLVideoPlayerCacheOperation : NSOperation

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

+ (instancetype)operationWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                  cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, strong, readonly) AVAssetResourceLoadingRequest *loadingRequest;

@end
