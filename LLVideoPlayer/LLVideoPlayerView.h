//
//  LLVideoPlayerView.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/24.
//  Copyright © 2016 mario. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LLVideoPlayerDefines.h"
#import "LLVideoPlayerLayerView.h"

/// LLVideoPlayerView: Low Level Video View

@interface LLVideoPlayerView : UIView

// The player's layer view
@property (nonatomic, strong) LLVideoPlayerLayerView *playerLayerView;

@end
