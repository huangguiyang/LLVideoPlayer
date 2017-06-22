//
//  NSHTTPURLResponse+LLVideoPlayer.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "NSString+LLVideoPlayer.h"

@implementation NSHTTPURLResponse (LLVideoPlayer)

- (BOOL)ll_supportRange
{
    return self.allHeaderFields[@"Content-Range"] != nil;
}

- (NSInteger)ll_totalLength
{
    // Get total content length
    
    // For example: "Content-Range" = "bytes 57933824-57999359/65904318"
    NSString *contentRange = self.allHeaderFields[@"Content-Range"];
    NSString *lengthString = [contentRange ll_decodeLengthFromContentRange];
    if (lengthString) {
        return [lengthString integerValue];
    }
    
    return [self expectedContentLength];
}

@end
