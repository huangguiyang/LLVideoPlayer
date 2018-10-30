//
//  LLVideoPlayerCacheLoader.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LLVideoPlayerCacheLoader : NSObject <AVAssetResourceLoaderDelegate>

- (instancetype)initWithURL:(NSURL *)streamURL;

@end
