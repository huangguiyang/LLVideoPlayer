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

@property (nonatomic, strong, readonly) NSString *cacheFilePath;

+ (instancetype)loaderWithCacheFilePath:(NSString *)filePath;

- (instancetype)initWithCacheFilePath:(NSString *)filePath;

@end
