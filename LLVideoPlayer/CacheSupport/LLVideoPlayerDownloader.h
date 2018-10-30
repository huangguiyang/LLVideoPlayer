//
//  LLVideoPlayerDownloader.h
//  LLVideoPlayer
//
//  Created by mario on 2018/10/26.
//

#import <Foundation/Foundation.h>

@interface LLVideoPlayerDownloader : NSObject

@property (nonatomic, assign) NSInteger maxConcurrentCount;

+ (instancetype)defaultDownloader;

- (void)preloadWithURL:(NSURL *)url;
- (void)preloadWithURL:(NSURL *)url bytes:(NSUInteger)bytes;
- (void)cancelPreloadWithURL:(NSURL *)url;
- (void)cancelAllPreloads;

@end
