//
//  LLVideoPlayerView.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/24.
//  Copyright © 2016 mario. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "LLVideoPlayerDefines.h"

/// LLVideoPlayerView: Low Level Video View

@interface LLVideoPlayerView : UIView

- (void)setPlayer:(AVPlayer *)player;

@end
