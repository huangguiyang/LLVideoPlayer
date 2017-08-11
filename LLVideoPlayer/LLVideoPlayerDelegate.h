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
@class LLVideoTrack;

/// LLVideoPlayerDelegate

@protocol LLVideoPlayerDelegate <NSObject>

@optional

#pragma mark - State Changed
- (BOOL)shouldVideoPlayer:(LLVideoPlayer *)videoPlayer changeStateTo:(LLVideoPlayerState)state;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willChangeStateTo:(LLVideoPlayerState)state;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didChangeStateFrom:(LLVideoPlayerState)state;

#pragma mark - Play Control
- (BOOL)shouldVideoPlayer:(LLVideoPlayer *)videoPlayer startVideo:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willStartVideo:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didStartVideo:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didPlayFrame:(LLVideoTrack *)track time:(NSTimeInterval)time;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didPlayToEnd:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer loadedTimeRanges:(NSArray<NSValue *> *)ranges track:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willContinuePlaying:(LLVideoTrack *)track;

#pragma mark - Error
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didFailWithError:(NSError *)error;

#pragma mark - 
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer durationDidLoad:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackBufferEmpty:(BOOL)bufferEmpty track:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackLikelyToKeepUp:(BOOL)likelyToKeepUp track:(LLVideoTrack *)track;

@end
