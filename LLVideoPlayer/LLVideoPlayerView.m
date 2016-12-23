//
//  LLVideoPlayerView.m
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/24.
//  Copyright © 2016 mario. All rights reserved.
//

#import "LLVideoPlayerView.h"
#import "LLVideoPlayerInternal.h"
#import "Masonry.h"

@implementation LLVideoPlayerView

#pragma mark - Initialize

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.playerLayerView = [LLVideoPlayerLayerView new];
        [self addSubview:self.playerLayerView];
        [self.playerLayerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self).with.insets(UIEdgeInsetsMake(0, 0, 0, 0));
        }];
    }
    return self;
}

- (void)dealloc
{
    
}

@end
