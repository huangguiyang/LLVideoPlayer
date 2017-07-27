//
//  LLVideoPlayerCacheHelper.h
//  Pods
//
//  Created by mario on 2017/6/28.
//
//

#import <Foundation/Foundation.h>

@interface LLVideoPlayerCacheHelper : NSObject

+ (void)clearAllCache;

+ (void)preloadWithURL:(NSURL *)url;

+ (void)cancelWithURL:(NSURL *)url;

+ (void)cancelAllPreloads;

@end
