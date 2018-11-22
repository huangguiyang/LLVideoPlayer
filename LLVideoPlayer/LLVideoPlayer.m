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
#import "LLVideoPlayerCacheLoader.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheFile.h"
#import "NSString+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "LLVideoPlayerDownloader.h"
#import "LLVideoPlayerCacheManager.h"

#if defined DEBUG
#define NSLog(...)  NSLog(__VA_ARGS__)
#else
#define NSLog(...)
#endif

typedef void (^VoidBlock) (void);

@interface LLVideoPlayer ()

@property (nonatomic, strong) id avTimeObserver;
@property (nonatomic, strong) LLVideoPlayerCacheLoader *resourceLoader;
@property (nonatomic, strong) NSMutableSet *failingURLs;
@property (nonatomic, assign) NSInteger lastFrameTime;

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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [self.view.layer addObserver:self forKeyPath:@"readyForDisplay" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (void)dealloc
{
    [self.view.layer removeObserver:self forKeyPath:@"readyForDisplay" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
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
            self.state = LLVideoPlayerStateContentLoading;
            [self playVideoTrack:self.track];
        };
        
        switch (self.state) {
            case LLVideoPlayerStateUnknown:
            case LLVideoPlayerStateError:
            case LLVideoPlayerStateDismissed:
            case LLVideoPlayerStateContentLoading:
            case LLVideoPlayerStateContentPaused:
                completionHandler();
                break;
            case LLVideoPlayerStateContentPlaying:
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

- (void)pauseContentWithCompletionHandler:(void (^)(void))completionHandler
{
    [self pauseContent:NO completionHandler:completionHandler];
}

- (void)pauseContent:(BOOL)isUserAction completionHandler:(void (^)(void))completionHandler
{
    ll_run_on_ui_thread(^{
        switch (self.avPlayerItem.status) {
            case AVPlayerItemStatusFailed:
                NSLog(@"Trying to pause content but AVPlayerItemStatusFailed");
                self.state = LLVideoPlayerStateError;
                return;
                break;
            case AVPlayerItemStatusUnknown:
                NSLog(@"Trying to pause content but AVPlayerItemStatusUnknown");
                self.state = LLVideoPlayerStateContentLoading;
                return;
                break;
            default:
                break;
        }
        
        switch (self.avPlayer.status) {
            case AVPlayerStatusFailed:
                NSLog(@"Trying to pause content but AVPlayerStatusFailed");
                self.state = LLVideoPlayerStateError;
                return;
                break;
            case AVPlayerStatusUnknown:
                NSLog(@"Trying to pause content but AVPlayerStatusUnknown");
                self.state = LLVideoPlayerStateContentLoading;
                return;
                break;
            default:
                break;
        }
        
        switch (self.state) {
            case LLVideoPlayerStateError:
                NSLog(@"Trying to pause content but LLVideoPlayerStateError");
                // fall through
            case LLVideoPlayerStateContentPlaying:
            case LLVideoPlayerStateContentPaused:
                self.state = LLVideoPlayerStateContentPaused;
                if (completionHandler) {
                    completionHandler();
                }
                break;
                
            case LLVideoPlayerStateContentLoading:
                NSLog(@"Trying to pause content but LLVideoPlayerStateContentLoading");
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
                NSLog(@"Trying to dismiss content at AVPlayerItemStatusFailed");
                break;
            case AVPlayerItemStatusUnknown:
                NSLog(@"Trying to dismiss content at AVPlayerItemStatusUnknown");
                break;
            default:
                break;
        }
        
        switch (self.avPlayer.status) {
            case AVPlayerStatusFailed:
                NSLog(@"Trying to dismiss content at AVPlayerStatusFailed");
                break;
            case AVPlayerStatusUnknown:
                NSLog(@"Trying to dismiss content at AVPlayerStatusUnknown");
                break;
            default:
                break;
        }
        
        switch (self.state) {
            case LLVideoPlayerStateContentPlaying:
                NSLog(@"Trying to dismiss content at LLVideoPlayerStateContentPlaying");
                [self pauseContent:NO completionHandler:nil];
                break;
            case LLVideoPlayerStateContentLoading:
                NSLog(@"Trying to dismiss content at LLVideoPlayerStateContentLoading");
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
    NSLog(@"seekToTimeInSecond: %f, userAction: %@", sec, isUserAction ? @"YES" : @"NO");
    [self.avPlayer ll_seekToTimeInSeconds:sec accurate:self.accurateSeek completionHandler:completionHandler];
}

- (void)seekToLastWatchedDuration
{
    [self seekToLastWatchedDuration:nil];
}

- (void)seekToLastWatchedDuration:(void (^)(BOOL finished))completionHandler;
{
    ll_run_on_ui_thread(^{
        float lastWatchedTime = [self.track.lastWatchedDuration floatValue];
        if (lastWatchedTime > 0) {
            if ([self.delegate respondsToSelector:@selector(videoPlayerWillContinuePlaying:)]) {
                [self.delegate videoPlayerWillContinuePlaying:self];
            }
        }
        
        NSLog(@"Seeking to last watched duration: %f", lastWatchedTime);
        
        [self.avPlayer ll_seekToTimeInSeconds:lastWatchedTime accurate:self.accurateSeek completionHandler:completionHandler];
    });
}

#pragma mark - AVPlayer

- (void)clearPlayer
{
    self.avTimeObserver = nil;
    [self.avPlayerItem.asset cancelLoading];
    self.avPlayerItem = nil;
    self.resourceLoader = nil;
    self.avPlayer = nil;
    [[self activePlayerView] setPlayer:nil];
    self.lastFrameTime = 0;
}

- (void)playVideoTrack:(LLVideoTrack *)track
{
    if ([self.delegate respondsToSelector:@selector(shouldVideoPlayerStartVideo:)]) {
        if (NO == [self.delegate shouldVideoPlayerStartVideo:self]) {
            return;
        }
    }
    [self clearPlayer];
    
    NSURL *streamURL = [track streamURL];
    if (nil == streamURL) {
        return;
    }
    
    [self playOnAVPlayer:streamURL playerLayerView:[self activePlayerView] track:track];
}

- (LLVideoPlayerView *)activePlayerView
{
    return self.view;
}

- (BOOL)sessionCacheEnabled
{
    if (NO == self.cacheSupportEnabled) {
        return NO;
    }
    if ([self.track.streamURL isFileURL]) {
        return NO;
    }
    if ([self.track.streamURL ll_m3u8]) {
        return NO;
    }
    if ([self.failingURLs containsObject:self.track.streamURL]) {
        return NO;
    }
    return YES;
}

- (void)playOnAVPlayer:(NSURL *)streamURL playerLayerView:(LLVideoPlayerView *)playerLayerView track:(LLVideoTrack *)track
{
    static NSString *kPlayableKey = @"playable";
    static NSString *kTracks = @"tracks";
    
    AVURLAsset *asset;
    
    if ([self sessionCacheEnabled]) {
        asset = [[AVURLAsset alloc] initWithURL:[streamURL ll_customSchemeURL] options:nil];
        self.resourceLoader = [[LLVideoPlayerCacheLoader alloc] initWithURL:streamURL];
        [asset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
    } else {
        asset = [[AVURLAsset alloc] initWithURL:streamURL options:nil];
    }
    self.avPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    [asset loadValuesAsynchronouslyForKeys:@[kPlayableKey, kTracks] completionHandler:^{
        ll_run_on_ui_thread(^{
            if (NO == [streamURL isEqual:self.track.streamURL]) {
                NSLog(@"URL dismatch: %@ loaded, but cuurent is %@",streamURL, self.track.streamURL);
                return;
            }
            if (self.state == LLVideoPlayerStateDismissed) {
                NSLog(@"Asset was dismissed while status %ld", (long)[asset statusOfValueForKey:kPlayableKey error:nil]);
                return;
            }
            NSError *error = nil;
            AVKeyValueStatus status = [asset statusOfValueForKey:kPlayableKey error:&error];
            if (status == AVKeyValueStatusLoaded) {
                NSLog(@"AVURLAsset loaded. [OK]");
                self.avPlayer = [self playerWithPlayerItem:self.avPlayerItem];
                [playerLayerView setPlayer:self.avPlayer];
            } else {
                NSLog(@"The asset's tracks were not loaded: %@", error);
                [self handleErrorCode:LLVideoPlayerErrorAssetLoadError track:track error:error];
            }
        });
    }];
}

- (AVPlayer*)playerWithPlayerItem:(AVPlayerItem *)playerItem
{
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    if ([player respondsToSelector:@selector(setAllowsExternalPlayback:)]) {
        player.allowsExternalPlayback = NO;
    }
    if ([player respondsToSelector:@selector(setAutomaticallyWaitsToMinimizeStalling:)]) {
        if (@available(iOS 10.0, *)) {
            [player setAutomaticallyWaitsToMinimizeStalling:NO];
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
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemPlaybackStalledNotification
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
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(playItemPlaybackStall:)
                                                         name:AVPlayerItemPlaybackStalledNotification
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
    [(AVPlayerLayer *)[self activePlayerView].layer setVideoGravity:videoGravity];
}

- (NSString *)videoGravity
{
    return [(AVPlayerLayer *)[self activePlayerView].layer videoGravity];
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
                    NSLog(@"AVPlayerStatusReadyToPlay");
                    if (self.avPlayerItem.status == AVPlayerItemStatusReadyToPlay) {
                        [self handlePlayerItemReadyToPlay];
                    }
                    break;
                case AVPlayerStatusFailed:
                    NSLog(@"AVPlayerStatusFailed");
                    [self handleErrorCode:LLVideoPlayerErrorAVPlayerFail track:self.track error:nil];
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
                    NSLog(@"AVPlayerItemStatusReadyToPlay");
                    if (self.avPlayer.status == AVPlayerStatusReadyToPlay) {
                        [self handlePlayerItemReadyToPlay];
                    }
                    break;
                case AVPlayerItemStatusFailed:
                    NSLog(@"AVPlayerStAVPlayerItemStatusFailedatusFailed");
                    [self handleErrorCode:LLVideoPlayerErrorAVPlayerItemFail track:self.track error:nil];
                    break;
                default:
                    break;
            }
        }
        
        /// playbackBufferEmpty
        
        if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            NSLog(@"playbackBufferEmpty: %@", self.avPlayerItem.playbackBufferEmpty ? @"YES" : @"NO");
            if (self.state == LLVideoPlayerStateContentPlaying &&
                [self currentTime] > 0 &&
                [self currentTime] < [self.avPlayer ll_currentItemDuration] - 1) {
                if ([self.delegate respondsToSelector:@selector(videoPlayer:playbackBufferEmpty:)]) {
                    [self.delegate videoPlayer:self playbackBufferEmpty:self.avPlayerItem.playbackBufferEmpty];
                }
            }
        }
        
        /// playbackLikelyToKeepUp
        
        if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            NSLog(@"playbackLikelyToKeepUp: %@", self.avPlayerItem.playbackLikelyToKeepUp ? @"YES" : @"NO");
            if (self.state == LLVideoPlayerStateContentPlaying) {
                if ([self.delegate respondsToSelector:@selector(videoPlayer:playbackLikelyToKeepUp:)]) {
                    [self.delegate videoPlayer:self playbackLikelyToKeepUp:self.avPlayerItem.playbackLikelyToKeepUp];
                }
                if (self.avPlayerItem.playbackLikelyToKeepUp && NO == [self isPlayingVideo]) {
                    [self.avPlayer play];
                }
            }
        }
        
        /// loadedTimeRanges
        if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            if ([self.delegate respondsToSelector:@selector(videoPlayer:loadedTimeRanges:)]) {
                [self.delegate videoPlayer:self loadedTimeRanges:self.avPlayerItem.loadedTimeRanges];
            }
        }
    } else if (object == self.view.layer) {
        /// LLVideoPlayerView
        
        /// readyToDisplay
        if ([keyPath isEqualToString:@"readyForDisplay"]) {
            AVPlayerLayer *layer = (AVPlayerLayer *)self.view.layer;
            NSLog(@"playerReadyForDisplay: %@", layer.readyForDisplay ? @"YES" : @"NO");
            if ([self.delegate respondsToSelector:@selector(videoPlayer:readyForDisplay:)]) {
                [self.delegate videoPlayer:self readyForDisplay:layer.readyForDisplay];
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
                if ([self.delegate respondsToSelector:@selector(videoPlayerWillStartVideo:)]) {
                    [self.delegate videoPlayerWillStartVideo:self];
                }
                
                [self seekToLastWatchedDuration:^(BOOL finished) {
                    if (finished) {
                        [self startContent];
                        
                        if ([self.delegate respondsToSelector:@selector(videoPlayerDidStartVideo:)]) {
                            [self.delegate videoPlayerDidStartVideo:self];
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
    
    NSTimeInterval duration = [self.avPlayer ll_currentItemDuration];
    if (duration > 1) {
        if (nil == self.track.totalDuration || (NSInteger)[self.track.totalDuration floatValue] != (NSInteger)duration) {
            self.track.totalDuration = [NSNumber numberWithFloat:duration];
            if ([self.delegate respondsToSelector:@selector(videoPlayer:durationDidLoad:)]) {
                [self.delegate videoPlayer:self durationDidLoad:self.track.totalDuration];
            }
        }
    }
    
    if (self.state != LLVideoPlayerStateContentPlaying) {
        return;
    }
    NSInteger thisSecond = (NSInteger)(timeInSeconds + 0.5f);
    if (thisSecond == self.lastFrameTime) {
        return;
    }
    self.lastFrameTime = thisSecond;
    
    if ([self.delegate respondsToSelector:@selector(videoPlayer:didPlayFrame:)]) {
        [self.delegate videoPlayer:self didPlayFrame:timeInSeconds];
    }
}

- (void)playerDidPlayToEnd:(NSNotification *)note
{
    NSLog(@"playerDidPlayToEnd: %@", note.object);
    AVPlayerItem *finishedItem = note.object;
    if (NO == [finishedItem isEqual:self.avPlayerItem]) {
        NSLog(@"[WRN] finished playerItem of another AVPlayer");
        return;
    }
    
    // is current player's item
    ll_run_on_ui_thread(^{
        [self clearPlayer];
        self.track.isPlayedToEnd = YES;
        self.state = LLVideoPlayerStateUnknown;
        if ([self.delegate respondsToSelector:@selector(videoPlayerDidPlayToEnd:)]) {
            [self.delegate videoPlayerDidPlayToEnd:self];
        }
    });
}

- (void)playItemPlaybackStall:(NSNotification *)note
{
    NSLog(@"playItemPlaybackStall: %@", note.object);
    AVPlayerItem *stallItem = note.object;
    if (NO == [stallItem isEqual:self.avPlayerItem]) {
        NSLog(@"[WRN] stall playerItem of another AVPlayer");
        return;
    }
    
    ll_run_on_ui_thread(^{
        if ([self.delegate respondsToSelector:@selector(videoPlayerPlaybackStalled:)]) {
            [self.delegate videoPlayerPlaybackStalled:self];
        }
    });
}

- (void)handleWillResignActive:(NSNotification *)note
{
    if (self.cacheSupportEnabled) {
        [LLVideoPlayer cleanCacheWithPolicy:self.cachePolicy];
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
        
        NSLog(@"Player State: %@ -> %@",
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

- (void)handleErrorCode:(LLVideoPlayerError)errorCode track:(LLVideoTrack *)track error:(NSError *)error
{
    NSLog(@"[ERROR] %@: %@", [LLVideoPlayerHelper errorCodeToString:errorCode], track);
    [self addFailingURL:track.streamURL];
    if (errorCode == LLVideoPlayerErrorAssetLoadError) {
        [LLVideoPlayer removeCacheForURL:track.streamURL];
    }
    if ([self.delegate respondsToSelector:@selector(videoPlayer:didFailWithError:)]) {
        [self.delegate videoPlayer:self didFailWithError:[NSError errorWithDomain:@"LLVideoPlayer" code:errorCode userInfo:error ? @{@"track":track, @"error": error} : @{@"track":track}]];
    }
}

- (void)addFailingURL:(NSURL *)url {
    if (nil == url) {
        return;
    }
    if (nil == self.failingURLs) {
        self.failingURLs = [NSMutableSet set];
    }
    if (self.failingURLs.count > 64) {
        [self.failingURLs removeAllObjects];
    }
    [self.failingURLs addObject:url];
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

#pragma mark - Cache Support

+ (void)cleanCacheWithPolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    [[LLVideoPlayerCacheManager defaultManager] cleanCacheWithPolicy:cachePolicy];
}

+ (void)clearAllCache
{
    [[LLVideoPlayerCacheManager defaultManager] clearAllCache];
}

+ (void)removeCacheForURL:(NSURL *)url
{
    [[LLVideoPlayerCacheManager defaultManager] removeCacheForURL:url];
}

+ (NSString *)cachePathForURL:(NSURL *)url
{
    if (nil == url || [url ll_m3u8]) {
        return nil;
    }
    if ([url isFileURL]) {
        return [url absoluteString];
    }
    LLVideoPlayerCacheFile *cacheFile = [[LLVideoPlayerCacheManager defaultManager] createCacheFileForURL:url];
    NSString *path = [cacheFile isComplete] ? cacheFile.cacheFilePath : nil;
    [[LLVideoPlayerCacheManager defaultManager] releaseCacheFileForURL:url];
    return path;
}

+ (BOOL)isCacheComplete:(NSURL *)url
{
    return [self cachePathForURL:url] != nil;
}

+ (void)preloadWithURL:(NSURL *)url
{
    [self preloadWithURL:url bytes:(1 << 20)];
}

+ (void)preloadWithURL:(NSURL *)url bytes:(NSUInteger)bytes
{
    if (nil == url || [url isFileURL] || [url ll_m3u8]) {
        return;
    }
    
    [[LLVideoPlayerDownloader defaultDownloader] preloadWithURL:url bytes:bytes];
}

+ (void)cancelPreloadWithURL:(NSURL *)url
{
    if (nil == url || [url isFileURL] || [url ll_m3u8]) {
        return;
    }
    
    [[LLVideoPlayerDownloader defaultDownloader] cancelPreloadWithURL:url];
}

+ (void)cancelAllPreloads
{
    [[LLVideoPlayerDownloader defaultDownloader] cancelAllPreloads];
}

@end
