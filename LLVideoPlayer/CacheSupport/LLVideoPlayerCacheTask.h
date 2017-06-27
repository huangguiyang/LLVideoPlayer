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
#import "LLVideoPlayerBasicOperation.h"

@interface LLVideoPlayerCacheTask : LLVideoPlayerBasicOperation

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSError *error;

@end
