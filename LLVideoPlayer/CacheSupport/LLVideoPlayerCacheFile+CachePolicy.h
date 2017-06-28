//
//  LLVideoPlayerCacheFile+CachePolicy.h
//  Pods
//
//  Created by mario on 2017/6/19.
//
//

#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerCachePolicy.h"

@interface LLVideoPlayerCacheFile (CachePolicy)

+ (void)checkCacheDirectoryWithCachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

@end
