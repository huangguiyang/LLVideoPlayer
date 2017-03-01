//
//  LLVideoPlayerView.m
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/24.
//  Copyright © 2016 mario. All rights reserved.
//

#import "LLVideoPlayerView.h"
#import "LLVideoPlayerInternal.h"

@implementation LLVideoPlayerView

#pragma mark - Initialize

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.playerLayerView = [LLVideoPlayerLayerView new];
        [self addSubview:self.playerLayerView];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.playerLayerView.frame = self.bounds;
}

@end
