# LLVideoPlayer

[![CI Status](https://travis-ci.org/huangguiyang/LLVideoPlayer.svg?branch=master)](https://travis-ci.org/mario/LLVideoPlayer)
[![Version](https://img.shields.io/cocoapods/v/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![License](https://img.shields.io/cocoapods/l/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)
[![Platform](https://img.shields.io/cocoapods/p/LLVideoPlayer.svg?style=flat)](http://cocoapods.org/pods/LLVideoPlayer)

A Low Level Video Player inspired by [VKVideoPlayer](https://github.com/viki-org/VKVideoPlayer).

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
