//
//  NSHTTPURLResponse+LLVideoPlayer.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "NSHTTPURLResponse+LLVideoPlayer.h"

@implementation NSHTTPURLResponse (LLVideoPlayer)

- (BOOL)ll_supportRange
{
    return self.allHeaderFields[@"Content-Range"] != nil;
}

- (NSInteger)ll_contentLength
{
    NSString *range = self.allHeaderFields[@"Content-Range"];
    if (range) {
        NSArray *ranges = [range componentsSeparatedByString:@"/"];
        if (ranges.count > 0) {
            NSString *lengthString = [[ranges lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            return [lengthString integerValue];
        }
    } else {
        return [self expectedContentLength];
    }
    return 0;
}

@end
