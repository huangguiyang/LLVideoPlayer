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
    // Get total content length
    
    // For example: "Content-Range" = "bytes 57933824-57999359/65904318"
    NSString *contentRange = self.allHeaderFields[@"Content-Range"];
    if (contentRange) {
        NSArray *ranges = [contentRange componentsSeparatedByString:@"/"];
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
