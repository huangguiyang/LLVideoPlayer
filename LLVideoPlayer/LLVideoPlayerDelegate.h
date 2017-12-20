//
//  LLVideoPlayerDelegate.h
//  LLVideoPlayer
//
//  Created by mario on 2016/12/8.
//  Copyright © 2016 mario. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LLVideoPlayerDefines.h"

@class LLVideoPlayer;

/// LLVideoPlayerDelegate

@protocol LLVideoPlayerDelegate <NSObject>

@optional

#pragma mark - State Changed
- (BOOL)shouldVideoPlayer:(LLVideoPlayer *)videoPlayer changeStateTo:(LLVideoPlayerState)state;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willChangeStateTo:(LLVideoPlayerState)state;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didChangeStateFrom:(LLVideoPlayerState)state;

#pragma mark - Play Control
- (BOOL)shouldVideoPlayerStartVideo:(LLVideoPlayer *)videoPlayer;
- (void)videoPlayerWillStartVideo:(LLVideoPlayer *)videoPlayer;
- (void)videoPlayerDidStartVideo:(LLVideoPlayer *)videoPlayer;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didPlayFrame:(NSTimeInterval)time;
- (void)videoPlayerDidPlayToEnd:(LLVideoPlayer *)videoPlayer;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer loadedTimeRanges:(NSArray<NSValue *> *)ranges;
- (void)videoPlayerWillContinuePlaying:(LLVideoPlayer *)videoPlayer;

#pragma mark - Error
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didFailWithError:(NSError *)error;

#pragma mark - 
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer durationDidLoad:(NSNumber *)duration;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackBufferEmpty:(BOOL)bufferEmpty;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackLikelyToKeepUp:(BOOL)likelyToKeepUp;
- (void)videoPlayerPlaybackStalled:(LLVideoPlayer *)videoPlayer;

@end
