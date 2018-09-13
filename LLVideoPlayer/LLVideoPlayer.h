//
//  LLVideoPlayer.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/24.
//  Copyright © 2016 mario. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerDefines.h"
#import "LLVideoPlayerView.h"
#import "LLVideoTrack.h"
#import "LLVideoPlayerHelper.h"
#import "LLVideoPlayerDelegate.h"
#import "LLVideoPlayerCachePolicy.h"

/// LLVideoPlayer: Low Level Video Player

@interface LLVideoPlayer : NSObject

@property (nonatomic, weak) id<LLVideoPlayerDelegate> delegate;
@property (nonatomic, assign) LLVideoPlayerState state;
@property (nonatomic, strong) LLVideoPlayerView *view;
@property (nonatomic, strong) LLVideoTrack *track;
@property (nonatomic, strong) AVPlayer *avPlayer;
@property (nonatomic, strong) AVPlayerItem *avPlayerItem;
@property (nonatomic, strong) NSString *videoGravity;
@property (nonatomic, assign) BOOL cacheSupportEnabled;
@property (nonatomic, strong) LLVideoPlayerCachePolicy *cachePolicy;

- (instancetype)initWithVideoPlayerView:(LLVideoPlayerView *)videoPlayerView;

#pragma mark - Load
- (void)loadVideoWithTrack:(LLVideoTrack *)track;
- (void)loadVideoWithStreamURL:(NSURL *)streamURL;
- (void)reloadCurrentVideoTrack;

#pragma mark - Control
- (void)playContent;
- (void)pauseContent;
- (void)pauseContentWithCompletionHandler:(void (^)(void))completionHandler;
- (void)pauseContent:(BOOL)isUserAction completionHandler:(void (^)(void))completionHandler;
- (void)dismissContent;
- (void)seekToTimeInSecond:(float)sec userAction:(BOOL)isUserAction completionHandler:(void (^)(BOOL finished))completionHandler;
- (void)seekToLastWatchedDuration;

#pragma mark - Data
- (double)currentBitRateInKbps;
- (NSTimeInterval)currentTime;
- (BOOL)stalling;

@end


@interface LLVideoPlayer (CacheSupport)

+ (void)clearAllCache;
+ (void)removeCacheForURL:(NSURL *)url;

+ (void)preloadWithURL:(NSURL *)url;
+ (void)cancelPreloadWithURL:(NSURL *)url;
+ (void)cancelAllPreloads;

+ (NSString *)cachePathForURL:(NSURL *)url;
+ (BOOL)isCacheComplete:(NSURL *)url;

+ (void)checkCacheDirectoryWithCachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy;

@end
