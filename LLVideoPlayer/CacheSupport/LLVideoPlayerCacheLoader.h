//
//  LLVideoPlayerCacheLoader.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCachePolicy.h"

@interface LLVideoPlayerCacheLoader : NSObject <AVAssetResourceLoaderDelegate>

+ (instancetype)loaderWithURL:(NSURL *)url cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

- (instancetype)initWithURL:(NSURL *)url cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

@end
