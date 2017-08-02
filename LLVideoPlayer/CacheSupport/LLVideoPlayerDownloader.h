//
//  LLVideoPlayerDownloader.h
//  Pods
//
//  Created by mario on 2017/7/21.
//
//

#import <Foundation/Foundation.h>
#import "LLVideoPlayerDownloadFile.h"

@interface LLVideoPlayerDownloader : NSObject

+ (NSString *)cacheDirectory;

+ (instancetype)defaultDownloader;

#pragma mark - Preload

- (void)preloadWithURL:(NSURL *)url bytes:(NSUInteger)bytes;

- (void)cancelWithURL:(NSURL *)url;

- (void)cancelAllPreloads;

+ (LLVideoPlayerDownloadFile *)getExternalDownloadFileWithName:(NSString *)name;

@end
