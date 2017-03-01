//
//  LLPlayerItemCacheLoader.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LLPlayerItemCacheLoader : NSObject <AVAssetResourceLoaderDelegate>

@property (nonatomic, strong, readonly) NSString *cacheFilePath;

+ (instancetype)cacheLoaderWithCacheFilePath:(NSString *)filePath;

- (instancetype)initWithCacheFilePath:(NSString *)filePath;

@end
