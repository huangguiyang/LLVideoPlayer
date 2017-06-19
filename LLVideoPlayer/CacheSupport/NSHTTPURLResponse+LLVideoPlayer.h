//
//  NSHTTPURLResponse+LLVideoPlayer.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

@interface NSHTTPURLResponse (LLVideoPlayer)

- (BOOL)ll_supportRange;

- (NSInteger)ll_totalLength;

@end
