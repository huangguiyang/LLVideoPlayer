//
//  LLVideoPlayerCacheFile+CachePolicy.h
//  Pods
//
//  Created by mario on 2017/6/19.
//
//

#import "LLVideoPlayerCacheFile.h"

@interface LLVideoPlayerCacheFile (CachePolicy)

+ (void)checkCacheWithFile:(NSString *)cacheFilePath policy:(LLVideoPlayerCachePolicy *)policy;

@end
