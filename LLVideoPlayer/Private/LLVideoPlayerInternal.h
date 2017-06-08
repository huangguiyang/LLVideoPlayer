//
//  LLVideoPlayerInternal.h
//  IMYVideoPlayer
//
//  Created by mario on 2016/12/2.
//  Copyright © 2016 mario. All rights reserved.
//

#ifndef LLVideoPlayerInternal_h
#define LLVideoPlayerInternal_h

#ifdef DEBUG
#define LLLog(...)  NSLog(__VA_ARGS__)
#else
#define LLLog(...)
#endif

#if defined(DEBUG) && defined(LL_TRACK_CACHE)
#define TLog(...)  NSLog(__VA_ARGS__)
#else
#define TLog(...)
#endif

#endif /* LLVideoPlayerInternal_h */
