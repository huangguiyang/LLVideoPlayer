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

- (instancetype)initWithCacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@end
