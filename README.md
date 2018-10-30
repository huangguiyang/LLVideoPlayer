# LLVideoPlayer

[![Version](https://img.shields.io/cocoapods/v/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![License](https://img.shields.io/cocoapods/l/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![Platform](https://img.shields.io/cocoapods/p/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)

A low level video player based on AVPlayer with cache support.



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

## Customize UI Controls

LLVideoPlayer comes without any UI controls for flexibility. Your can add your custom contols to the container view `LLVideoPlayerView`.

## Cache Support

LLVideoPlayer supports customize cache policy. To enable the cache support (default is disable):

```
player.cacheSupportEnabled = YES;
```

To set your customize cache policy:

```
player.cachePolicy = your_policy;
```

See `LLVideoPlayerCachePolicy` for more details.

## Preload Support

```
[LLVideoPlayer preloadWithURL:url];
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
