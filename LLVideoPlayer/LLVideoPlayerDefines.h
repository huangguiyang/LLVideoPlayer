//
//  LLVideoPlayerDefines.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/11/29.
//  Copyright © 2016 mario. All rights reserved.
//

#ifndef LLVideoPlayerDefines_h
#define LLVideoPlayerDefines_h

#import <Foundation/Foundation.h>

#pragma mark - Error Code
typedef NS_ENUM(NSInteger, LLVideoPlayerError) {
    LLVideoPlayerErrorNone,
    LLVideoPlayerErrorAssetLoadError,
    LLVideoPlayerErrorStreamNotFound,
    LLVideoPlayerErrorAVPlayerFail,
    LLVideoPlayerErrorAVPlayerItemFail,
    LLVideoPlayerErrorUnknown
};

#pragma mark - Player State
typedef NS_ENUM(NSInteger, LLVideoPlayerState) {
    LLVideoPlayerStateUnknown,
    LLVideoPlayerStateContentLoading,
    LLVideoPlayerStateContentPlaying,
    LLVideoPlayerStateContentPaused,
    LLVideoPlayerStateDismissed,
    LLVideoPlayerStateError
};

#endif /* LLVideoPlayerDefines_h */
