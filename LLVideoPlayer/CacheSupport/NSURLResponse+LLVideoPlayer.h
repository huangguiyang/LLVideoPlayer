//
//  NSURLResponse+LLVideoPlayer.h
//  Pods
//
//  Created by mario on 2017/8/22.
//
//

#import <Foundation/Foundation.h>

@interface NSURLResponse (LLVideoPlayer)

- (BOOL)ll_supportRange;

- (NSInteger)ll_totalLength;

@end
