# LLVideoPlayer

[![Version](https://img.shields.io/cocoapods/v/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![License](https://img.shields.io/cocoapods/l/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![Platform](https://img.shields.io/cocoapods/p/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)

A low level video player based on AVPlayer with cache and preload support.



- [x] Simple and flexible
- [x] Cache support
- [x] Preload support


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

## Delegate

There are some significant delegate methods you may be interested in:

```
// The first frame of the video is ready to display.
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer readyForDisplay:(BOOL)readyForDisplay;

// The duration is available.
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer durationDidLoad:(NSNumber *)duration;

// The buffer is empty or not.
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackBufferEmpty:(BOOL)bufferEmpty;

// The video is likely to keepup or not.
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer playbackLikelyToKeepUp:(BOOL)likelyToKeepUp;

// The playback is stalled.
- (void)videoPlayerPlaybackStalled:(LLVideoPlayer *)videoPlayer;

/// more...
```

See `LLVideoPlayerDelegate` for more details.

## Customize UI Controls

LLVideoPlayer comes without any UI controls for flexibility. Your can add your custom contols to the container view `LLVideoPlayerView`.

## Cache Support

LLVideoPlayer supports customize cache policy. To enable the cache support (default is disable):

```
player.cacheSupportEnabled = YES;	// That's all, so simple...
```

To set your customize cache policy:

```
LLVideoPlayerCachePolicy *policy = [LLVideoPlayerCachePolicy new];
policy.diskCapacity = 500ULL << 20;	// max disk capacity in bytes, for example 500MiB
policy.outdatedHours = 7 *24;		// outdated hours, for example 7 days

player.cachePolicy = policy;
```

See `LLVideoPlayerCachePolicy` for more details.

To clear cache manually:

```
[LLVideoPlayer clearAllCache];
```

## Preload Support

```
// start a preload request
[LLVideoPlayer preloadWithURL:url];

// start a preload request with specified bytes
[LLVideoPlayer preloadWithURL:url bytes:(1 << 20)];

// cancel a preload request
[LLVideoPlayer cancelPreloadWithURL:url];

// cancel all preload requests
[LLVideoPlayer cancelAllPreloads];
```

## Requirements

iOS 7 or above

## Installation

LLVideoPlayer is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "LLVideoPlayer"
```

## Author

mario, guiyang.huang@gmail.com

## License

LLVideoPlayer is available under the MIT license. See the LICENSE file for more info.
