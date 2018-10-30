//
//  LLVideoPlayerLoadingRequest.h
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCacheFile.h"

@class LLVideoPlayerLoadingRequest;
@protocol LLVideoPlayerLoadingRequestDelegate <NSObject>

- (void)request:(LLVideoPlayerLoadingRequest *)operation didComepleteWithError:(NSError *)error;

@end

@interface LLVideoPlayerLoadingRequest : NSObject

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, strong, readonly) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, weak) id<LLVideoPlayerLoadingRequestDelegate> delegate;

- (void)resume;
- (void)cancel;

@end
