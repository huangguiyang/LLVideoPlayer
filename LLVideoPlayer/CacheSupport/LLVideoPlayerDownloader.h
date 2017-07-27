//
//  LLVideoPlayerDownloader.h
//  Pods
//
//  Created by mario on 2017/7/21.
//
//

#import <Foundation/Foundation.h>

@interface LLVideoPlayerDownloader : NSObject

+ (NSString *)cacheDirectory;

+ (instancetype)defaultDownloader;

#pragma mark - Preload

- (void)preloadWithURL:(NSURL *)url;

- (void)cancelWithURL:(NSURL *)url;

- (void)cancelAllPreloads;

@end
