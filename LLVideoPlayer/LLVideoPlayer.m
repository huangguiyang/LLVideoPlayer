//
//  LLVideoPlayerImpl.m
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/24.
//  Copyright © 2016 mario. All rights reserved.
//

#import "LLVideoPlayer.h"
#import "LLVideoTrack.h"
#import <AVFoundation/AVFoundation.h>
#import "AVPlayer+LLPlayer.h"
#import "LLVideoPlayerInternal.h"
#import "LLVideoPlayerCacheLoader.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheFile.h"

typedef void (^VoidBlock) (void);

@interface LLVideoPlayer ()

@property (nonatomic, strong) id avTimeObserver;
@property (nonatomic, strong) AVURLAsset *loadingAsset;
@property (nonatomic, strong) LLVideoPlayerCacheLoader *resourceLoader;

@end

@implementation LLVideoPlayer

- (instancetype)init
{
    return [self initWithVideoPlayerView:[LLVideoPlayerView new]];
}

- (instancetype)initWithVideoPlayerView:(LLVideoPlayerView *)videoPlayerView
{
    self = [super init];
    if (self) {
        self.view = videoPlayerView;
        self.state = LLVideoPlayerStateUnknown;
    }
    return self;
}

- (void)dealloc
{
    [self clearPlayer];
}

#pragma mark - Load

- (void)loadVideoWithTrack:(LLVideoTrack *)track
{
    self.track = track;
    self.state = LLVideoPlayerStateContentLoading;
    
    VoidBlock completionHandler = ^{
        [self playVideoTrack:self.track];
    };
    switch (self.state) {
        case LLVideoPlayerStateError:
        case LLVideoPlayerStateContentPaused:
        case LLVideoPlayerStateContentLoading:
            completionHandler();
            break;
        case LLVideoPlayerStateContentPlaying:
            [self pauseContent:NO completionHandler:completionHandler];
            break;
        case LLVideoPlayerStateDismissed:
        case LLVideoPlayerStateUnknown:
        default:
            break;
    }
}

- (void)loadVideoWithStreamURL:(NSURL *)streamURL
{
    [self loadVideoWithTrack:[[LLVideoTrack alloc] initWithStreamURL:streamURL]];
}

- (void)reloadCurrentVideoTrack
{
    ll_run_on_ui_thread(^{
        VoidBlock completionHandler = ^{
            self.track.lastWatchedDuration = nil;
            self.track.isPlayedToEnd = NO;
            self.track.isCacheComplete = NO;
            self.state = LLVideoPlayerStateContentLoading;
            [self playVideoTrack:self.track];
        };
        
        switch (self.state) {
            case LLVideoPlayerStateUnknown:
            case LLVideoPlayerStateError:
            case LLVideoPlayerStateDismissed:
            case LLVideoPlayerStateContentLoading:
            case LLVideoPlayerStateContentPaused:
                LLLog(@"Reload stream now.");
                completionHandler();
                break;
            case LLVideoPlayerStateContentPlaying:
                LLLog(@"Reload stream after pause.");
                [self pauseContent:NO completionHandler:completionHandler];
                break;
            default:
                break;
        }
    });
}

#pragma mark - Control

- (void)startContent
{
    ll_run_on_ui_thread(^{
        if (self.state == LLVideoPlayerStateContentLoading) {
            self.state = LLVideoPlayerStateContentPlaying;
        }
    });
}

- (void)playContent
{
    ll_run_on_ui_thread(^{
        if (self.state == LLVideoPlayerStateContentPaused) {
            self.state = LLVideoPlayerStateContentPlaying;
        }
    });
}

- (void)pauseContent
{
    [self pauseContent:NO completionHandler:nil];
}

- (void)pauseContentWithCompletionHandler:(void (^)())completionHandler
{
    [self pauseContent:NO completionHandler:completionHandler];
}

- (void)pauseContent:(BOOL)isUserAction completionHandler:(void (^)())completionHandler
{
    ll_run_on_ui_thread(^{
        switch (self.avPlayerItem.status) {
            case AVPlayerItemStatusFailed:
                LLLog(@"Trying to pause content but AVPlayerItemStatusFailed");
                self.state = LLVideoPlayerStateError;
                return;
                break;
            case AVPlayerItemStatusUnknown:
                LLLog(@"Trying to pause content but AVPlayerItemStatusUnknown");
                self.state = LLVideoPlayerStateContentLoading;
                return;
                break;
            default:
                break;
        }
        
        switch (self.avPlayer.status) {
            case AVPlayerStatusFailed:
                LLLog(@"Trying to pause content but AVPlayerStatusFailed");
                self.state = LLVideoPlayerStateError;
                return;
                break;
            case AVPlayerStatusUnknown:
                LLLog(@"Trying to pause content but AVPlayerStatusUnknown");
                self.state = LLVideoPlayerStateContentLoading;
                return;
                break;
            default:
                break;
        }
        
        switch (self.state) {
            case LLVideoPlayerStateError:
                LLLog(@"Trying to pause content but LLVideoPlayerStateError");
                // fall through
            case LLVideoPlayerStateContentPlaying:
            case LLVideoPlayerStateContentPaused:
                self.state = LLVideoPlayerStateContentPaused;
                if (completionHandler) {
                    completionHandler();
                }
                break;
                
            case LLVideoPlayerStateContentLoading:
                LLLog(@"Trying to pause content but LLVideoPlayerStateContentLoading");
                break;
                
            case LLVideoPlayerStateDismissed:
            case LLVideoPlayerStateUnknown:
            default:
                break;
        }
    });
}

- (void)dismissContent
{
    ll_run_on_ui_thread(^{
        switch (self.avPlayerItem.status) {
            case AVPlayerItemStatusFailed:
                LLLog(@"Trying to dismiss content at AVPlayerItemStatusFailed");
                break;
            case AVPlayerItemStatusUnknown:
                LLLog(@"Trying to dismiss content at AVPlayerItemStatusUnknown");
                [self.loadingAsset cancelLoading];
                self.loadingAsset = nil;
                break;
            default:
                break;
        }
        
        switch (self.avPlayer.status) {
            case AVPlayerStatusFailed:
                LLLog(@"Trying to dismiss content at AVPlayerStatusFailed");
                break;
            case AVPlayerStatusUnknown:
                LLLog(@"Trying to dismiss content at AVPlayerStatusUnknown");
                [self.loadingAsset cancelLoading];
                self.loadingAsset = nil;
                break;
            default:
                break;
        }
        
        switch (self.state) {
            case LLVideoPlayerStateContentPlaying:
                LLLog(@"Trying to dismiss content at LLVideoPlayerStateContentPlaying");
                [self pauseContent:NO completionHandler:nil];
                break;
            case LLVideoPlayerStateContentLoading:
                LLLog(@"Trying to dismiss content at LLVideoPlayerStateContentLoading");
                break;
            case LLVideoPlayerStateContentPaused:
                break;
            case LLVideoPlayerStateError:
            case LLVideoPlayerStateDismissed:
            case LLVideoPlayerStateUnknown:
            default:
                break;
        }
        
        self.state = LLVideoPlayerStateDismissed;
    });
}

- (void)seekToTimeInSecond:(float)sec userAction:(BOOL)isUserAction completionHandler:(void (^)(BOOL finished))completionHandler
{
    LLLog(@"seekToTimeInSecond: %f, userAction: %@", sec, isUserAction ? @"YES" : @"NO");
    [self.avPlayer ll_seekToTimeInSeconds:sec completionHandler:completionHandler];
}

- (void)seekToLastWatchedDuration
{
    [self seekToLastWatchedDuration:nil];
}

- (void)seekToLastWatchedDuration:(void (^)(BOOL finished))completionHandler;
{
    ll_run_on_ui_thread(^{
        float lastWatchedTime = [self.track.lastWatchedDuration floatValue];
        if ([self.delegate respondsToSelector:@selector(videoPlayer:adjustLastWatchedDuration:)]) {
            lastWatchedTime = [self.delegate videoPlayer:self adjustLastWatchedDuration:lastWatchedTime];
        } else {
            if (lastWatchedTime > 5) {
                lastWatchedTime -= 1;
            }
        }
        
        LLLog(@"Seeking to last watched duration: %f", lastWatchedTime);
        
        [self.avPlayer ll_seekToTimeInSeconds:lastWatchedTime completionHandler:completionHandler];
    });
}

#pragma mark - AVPlayer

- (void)clearPlayer
{
    self.avTimeObserver = nil;
    self.avPlayer = nil;
    self.avPlayerItem = nil;
    self.loadingAsset = nil;
    self.resourceLoader = nil;
}

- (void)playVideoTrack:(LLVideoTrack *)track
{
    if ([self.delegate respondsToSelector:@selector(shouldVideoPlayer:startVideo:)]) {
        if (NO == [self.delegate shouldVideoPlayer:self startVideo:track]) {
            return;
        }
    }
    [self clearPlayer];
    
    NSURL *streamURL = [track streamURL];
    if (nil == streamURL) {
        return;
    }
    
    [self playOnAVPlayer:streamURL playerLayerView:[self activePlayerView].playerLayerView track:track];
}

- (LLVideoPlayerView *)activePlayerView
{
    return self.view;
}

- (BOOL)sessionCacheEnabled
{
    return self.cacheSupportEnabled && NO == [self.track.streamURL isFileURL];
}

- (void)playOnAVPlayer:(NSURL *)streamURL playerLayerView:(LLVideoPlayerLayerView *)playerLayerView track:(LLVideoTrack *)track
{
    static NSString *kPlayableKey = @"playable";
    static NSString *kTracks = @"tracks";
    AVURLAsset *asset;
    
    if ([self sessionCacheEnabled]) {
        asset = [[AVURLAsset alloc] initWithURL:[streamURL ll_customSchemeURL] options:nil];
        self.resourceLoader = [LLVideoPlayerCacheLoader loaderWithURL:streamURL cachePolicy:self.cachePolicy];
        [asset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
        track.isCacheComplete = [self.resourceLoader isCacheComplete];
    } else {
        asset = [[AVURLAsset alloc] initWithURL:streamURL options:nil];
    }
    
    [asset loadValuesAsynchronouslyForKeys:@[kPlayableKey, kTracks] completionHandler:^{
        ll_run_on_ui_thread(^{
            if (NO == [streamURL isEqual:self.track.streamURL]) {
                LLLog(@"URL dismatch: %@ loaded, but cuurent is %@",streamURL, self.track.streamURL);
                return;
            }
            if (self.state == LLVideoPlayerStateDismissed) {
                return;
            }
            NSError *error = nil;
            AVKeyValueStatus status = [asset statusOfValueForKey:kPlayableKey error:&error];
            if (status == AVKeyValueStatusLoaded) {
                LLLog(@"AVURLAsset loaded. [OK]");
                self.avPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
                self.avPlayer = [self playerWithPlayerItem:self.avPlayerItem];
                [playerLayerView setPlayer:self.avPlayer];
                self.loadingAsset = nil;
            } else {
                LLLog(@"The asset's tracks were not loaded: %@", error);
                [LLVideoPlayerCacheHelper clearAllCache];
                [self handleErrorCode:LLVideoPlayerErrorAssetLoadError track:track];
            }
        });
    }];
    self.loadingAsset = asset;
}

- (AVPlayer*)playerWithPlayerItem:(AVPlayerItem *)playerItem
{
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    if ([player respondsToSelector:@selector(setAllowsExternalPlayback:)]) {
        player.allowsExternalPlayback = NO;
    }
    if ([player respondsToSelector:@selector(setAutomaticallyWaitsToMinimizeStalling:)]) {
        if ([self sessionCacheEnabled]) {
            [player setAutomaticallyWaitsToMinimizeStalling:NO];
        } else {
            [player setAutomaticallyWaitsToMinimizeStalling:YES];
        }
    }
    return player;
}

- (void)setAvPlayer:(AVPlayer *)avPlayer
{
    if (_avPlayer != avPlayer) {
        self.avTimeObserver = nil;
        [_avPlayer removeObserver:self forKeyPath:@"status"];
        _avPlayer = avPlayer;
        if (avPlayer) {
            __weak __typeof(self) weakSelf = self;
            avPlayer.volume = [AVAudioSession sharedInstance].outputVolume;
            [avPlayer addObserver:self forKeyPath:@"status" options:0 context:nil];
            self.avTimeObserver = [avPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
                [weakSelf periodicTimeObserver:time];
            }];
        }
    }
}

- (void)setAvPlayerItem:(AVPlayerItem *)avPlayerItem
{
    if (_avPlayerItem != avPlayerItem) {
        [_avPlayerItem removeObserver:self forKeyPath:@"status"];
        [_avPlayerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_avPlayerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [_avPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:nil];
        _avPlayerItem = avPlayerItem;
        if (avPlayerItem) {
            [avPlayerItem addObserver:self forKeyPath:@"status" options:0 context:nil];
            [avPlayerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
            [avPlayerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
            [avPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(playerDidPlayToEnd:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:nil];
        }
    }
}

- (void)setAvTimeObserver:(id)avTimeObserver
{
    if (_avTimeObserver) {
        [self.avPlayer removeTimeObserver:_avTimeObserver];
    }
    _avTimeObserver = avTimeObserver;
}

- (void)setVideoGravity:(NSString *)videoGravity
{
    [(AVPlayerLayer *)self.view.playerLayerView.layer setVideoGravity:videoGravity];
}

- (NSString *)videoGravity
{
    return [(AVPlayerLayer *)self.view.playerLayerView.layer videoGravity];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (object == self.avPlayer) {
        /// AVPlayer
        
        /// status
        
        if ([keyPath isEqualToString:@"status"]) {
            switch (self.avPlayer.status) {
                case AVPlayerStatusReadyToPlay:
                    LLLog(@"AVPlayerStatusReadyToPlay");
                    if (self.avPlayerItem.status == AVPlayerItemStatusReadyToPlay) {
                        [self handlePlayerItemReadyToPlay];
                    }
                    break;
                case AVPlayerStatusFailed:
                    LLLog(@"AVPlayerStatusFailed");
                    [self handleErrorCode:LLVideoPlayerErrorAVPlayerFail track:self.track];
                    break;
                default:
                    break;
            }
        }
        
    } else if (object == self.avPlayerItem) {
        /// AVPlayerItem
        
        /// status
        
        if ([keyPath isEqualToString:@"status"]) {
            switch (self.avPlayerItem.status) {
                case AVPlayerItemStatusReadyToPlay:
                    LLLog(@"AVPlayerItemStatusReadyToPlay");
                    if (self.avPlayer.status == AVPlayerStatusReadyToPlay) {
                        [self handlePlayerItemReadyToPlay];
                    }
                    break;
                case AVPlayerItemStatusFailed:
                    LLLog(@"AVPlayerStAVPlayerItemStatusFailedatusFailed");
                    [self handleErrorCode:LLVideoPlayerErrorAVPlayerItemFail track:self.track];
                    break;
                default:
                    break;
            }
        }
        
        /// playbackBufferEmpty
        
        if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            LLLog(@"playbackBufferEmpty: %@", self.avPlayerItem.playbackBufferEmpty ? @"YES" : @"NO");
            if (self.state == LLVideoPlayerStateContentPlaying &&
                [self currentTime] > 0 &&
                [self currentTime] < [self.avPlayer ll_currentItemDuration] - 1) {
                if ([self.delegate respondsToSelector:@selector(videoPlayer:playbackBufferEmpty:track:)]) {
                    [self.delegate videoPlayer:self playbackBufferEmpty:self.avPlayerItem.playbackBufferEmpty track:self.track];
                }
            }
        }
        
        /// playbackLikelyToKeepUp
        
        if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            LLLog(@"playbackLikelyToKeepUp: %@", self.avPlayerItem.playbackLikelyToKeepUp ? @"YES" : @"NO");
            if (self.state == LLVideoPlayerStateContentPlaying) {
                if ([self.delegate respondsToSelector:@selector(videoPlayer:playbackLikelyToKeepUp:track:)]) {
                    [self.delegate videoPlayer:self playbackLikelyToKeepUp:self.avPlayerItem.playbackLikelyToKeepUp track:self.track];
                }
                if (self.avPlayerItem.playbackLikelyToKeepUp && NO == [self isPlayingVideo]) {
                    [self.avPlayer play];
                }
            }
        }
        
        /// loadedTimeRanges
        if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            if ([self.delegate respondsToSelector:@selector(videoPlayer:loadedTimeRanges:track:)]) {
                [self.delegate videoPlayer:self loadedTimeRanges:self.avPlayerItem.loadedTimeRanges track:self.track];
            }
        }
    }
}

#pragma mark - Events

- (void)handlePlayerItemReadyToPlay
{
    ll_run_on_ui_thread(^{
        switch (self.state) {
            case LLVideoPlayerStateContentLoading:
            case LLVideoPlayerStateError: {
                if ([self.delegate respondsToSelector:@selector(videoPlayer:willStartVideo:)]) {
                    [self.delegate videoPlayer:self willStartVideo:self.track];
                }
                
                [self seekToLastWatchedDuration:^(BOOL finished) {
                    if (finished) {
                        [self startContent];
                        
                        if ([self.delegate respondsToSelector:@selector(videoPlayer:didStartVideo:)]) {
                            [self.delegate videoPlayer:self didStartVideo:self.track];
                        }
                    }
                }];
            }
                break;
                
            case LLVideoPlayerStateContentPaused:
                break;
                
            case LLVideoPlayerStateContentPlaying:
            case LLVideoPlayerStateDismissed:
            case LLVideoPlayerStateUnknown:
            default:
                break;
        }
    });
}

#pragma mark - Notifications

- (void)periodicTimeObserver:(CMTime)time
{
    NSTimeInterval timeInSeconds = CMTimeGetSeconds(time);
    
    if (timeInSeconds <= 0) {
        return;
    }
        
    if ([self.avPlayer ll_currentItemDuration] > 1) {
        if (nil == self.track.totalDuration) {
            self.track.totalDuration = [NSNumber numberWithFloat:[self.avPlayer ll_currentItemDuration]];
            if ([self.delegate respondsToSelector:@selector(videoPlayer:durationDidLoad:)]) {
                [self.delegate videoPlayer:self durationDidLoad:self.track];
            }
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(videoPlayer:didPlayFrame:time:)]) {
        [self.delegate videoPlayer:self didPlayFrame:self.track time:timeInSeconds];
    }
}

- (void)playerDidPlayToEnd:(NSNotification *)note
{
    LLLog(@"playerDidPlayToEnd: %@", note);
    AVPlayerItem *finishedItem = (AVPlayerItem *)note.object;
    if (finishedItem == self.avPlayerItem) {
        // is current player's item
        ll_run_on_ui_thread(^{
            self.track.isPlayedToEnd = YES;
            self.state = LLVideoPlayerStateUnknown;
            if ([self.delegate respondsToSelector:@selector(videoPlayer:didPlayToEnd:)]) {
                [self.delegate videoPlayer:self didPlayToEnd:self.track];
            }
        });
    } else {
        LLLog(@"[WRN] finished playerItem of another AVPlayer");
    }
}

#pragma mark - State Changed

- (void)setState:(LLVideoPlayerState)newState
{
    if (self.state == newState) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(shouldVideoPlayer:changeStateTo:)]) {
        if (NO == [self.delegate shouldVideoPlayer:self changeStateTo:newState]) {
            return;
        }
    }
    
    ll_run_on_ui_thread(^{
        if ([self.delegate respondsToSelector:@selector(videoPlayer:willChangeStateTo:)]) {
            [self.delegate videoPlayer:self willChangeStateTo:newState];
        }
        
        LLVideoPlayerState oldState = self.state;
        switch (oldState) {
            case LLVideoPlayerStateContentLoading:
                break;
            case LLVideoPlayerStateContentPlaying:
                break;
            case LLVideoPlayerStateContentPaused:
                break;
            case LLVideoPlayerStateError:
                break;
            case LLVideoPlayerStateDismissed:
                break;
            case LLVideoPlayerStateUnknown:
            default:
                break;
        }
        
        LLLog(@"Player State: %@ -> %@",
              [LLVideoPlayerHelper playerStateToString:oldState],
              [LLVideoPlayerHelper playerStateToString:newState]);
        
        _state = newState;
        switch (newState) {
            case LLVideoPlayerStateContentLoading:
                break;
            case LLVideoPlayerStateContentPlaying:
                [self.avPlayer play];
                break;
            case LLVideoPlayerStateContentPaused:
                self.track.lastWatchedDuration = [NSNumber numberWithFloat:[self currentTime]];
                [self.avPlayer pause];
                break;
            case LLVideoPlayerStateError:
                [self.avPlayer pause];
                break;
            case LLVideoPlayerStateDismissed:
                [self clearPlayer];
                break;
            case LLVideoPlayerStateUnknown:
            default:
                break;
        }
        
        if ([self.delegate respondsToSelector:@selector(videoPlayer:didChangeStateFrom:)]) {
            [self.delegate videoPlayer:self didChangeStateFrom:oldState];
        }
    });
}

#pragma mark - Error

- (void)handleErrorCode:(LLVideoPlayerError)errorCode track:(LLVideoTrack *)track
{
    LLLog(@"[ERROR] %@: %@", [LLVideoPlayerHelper errorCodeToString:errorCode], track);
    if ([self.delegate respondsToSelector:@selector(videoPlayer:didFailWithError:)]) {
        [self.delegate videoPlayer:self didFailWithError:[NSError errorWithDomain:@"LLVideoPlayer" code:errorCode userInfo:@{@"track":track}]];
    }
}

#pragma mark - Misc

- (double)currentBitRateInKbps
{
    return [self.avPlayerItem.accessLog.events.lastObject observedBitrate]/1000;
}

- (NSTimeInterval)currentTime
{
    return CMTimeGetSeconds([self.avPlayer ll_currentCMTime]);
}

- (BOOL)stalling
{
    return self.avPlayerItem.playbackBufferEmpty || NO == self.avPlayerItem.playbackLikelyToKeepUp;
}

- (BOOL)isPlayingVideo
{
    return self.avPlayer && self.avPlayer.rate != 0.0;
}

@end
