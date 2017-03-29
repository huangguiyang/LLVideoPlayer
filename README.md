# LLVideoPlayer

[![Version](https://img.shields.io/cocoapods/v/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![License](https://img.shields.io/cocoapods/l/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![Platform](https://img.shields.io/cocoapods/p/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)

A Low Level Video Player inspired by [VKVideoPlayer](https://github.com/viki-org/VKVideoPlayer).



- [x] simple and flexible
- [x] customize cache support
- [ ] AirPlay support


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

```
// create
self.player = [[LLVideoPlayer alloc] init];
[self.view addSubview:self.player.view];
self.player.view.frame = CGRectMake(10, 80, 300, 200);
self.player.delegate = self;


// load
NSURL *url = [NSURL URLWithString:@"<your stream url>"];  
[self.player loadVideoWithStreamURL:url];


// pause
[self.player pauseContent];

// play
[self.player playContent];

// dismiss
[self.player dismissContent];

// delegate
// see the header file for details.
```

```
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

#pragma mark - Error
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didFailWithError:(NSError *)error;

#pragma mark - 
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer durationDidLoad:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackBufferEmpty:(BOOL)bufferEmpty track:(LLVideoTrack *)track;
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackLikelyToKeepUp:(BOOL)likelyToKeepUp track:(LLVideoTrack *)track;

@end
```

## Customize UI Controls

LLVideoPlayer comes without any UI controls for flexibility. Your can add your custom contols to the container view `LLVideoPlayerView`.

## Customize Cache Support

LLVideoPlayer supports customize cache policy. To enable the cache support (default is disable):

```
player.cacheSupportEnabled = YES;
```

To set your customize cache policy:

```
player.cachePolicy = your_policy;
```

See `LLVideoPlayerCachePolicy` for more details.

## Requirements

iOS 7 or above

## Installation

LLVideoPlayer is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "LLVideoPlayer"
```

## Author

mario, mohu3g@163.com

## License

LLVideoPlayer is available under the MIT license. See the LICENSE file for more info.
