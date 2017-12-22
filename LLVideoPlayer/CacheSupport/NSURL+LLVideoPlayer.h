//
//  NSURL+LLVideoPlayer.h
//  Pods
//
//  Created by mario on 2017/2/22.
//
//

#import <Foundation/Foundation.h>

@interface NSURL (LLVideoPlayer)

- (NSURL *)ll_customSchemeURL;

- (NSURL *)ll_originalSchemeURL;

- (BOOL)ll_m3u8;

@end
