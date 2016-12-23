//
//  LLVideoPlayerLayerView.m
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/25.
//  Copyright © 2016 mario. All rights reserved.
//

#import "LLVideoPlayerLayerView.h"

@implementation LLVideoPlayerLayerView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (void)setPlayer:(AVPlayer *)player
{
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

@end
