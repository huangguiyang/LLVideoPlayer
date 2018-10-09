//
//  LLVideoPlayerCacheLoader.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerCacheFile.h"

@interface LLVideoPlayerCacheLoader : NSObject <AVAssetResourceLoaderDelegate>

+ (instancetype)loaderWithCacheFile:(LLVideoPlayerCacheFile *)cacheFile;

- (instancetype)initWithCacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, strong, readonly) LLVideoPlayerCacheFile *cacheFile;

@end
