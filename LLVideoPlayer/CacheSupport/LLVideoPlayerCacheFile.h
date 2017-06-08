//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>
#import "LLVideoPlayerCachePolicy.h"

@interface LLVideoPlayerCacheFile : NSObject

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

- (instancetype)initWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

+ (NSString *)cacheDirectory;

@end
