//
//  NSURLResponse+LLVideoPlayer.m
//  Pods
//
//  Created by mario on 2017/8/22.
//
//

#import "NSURLResponse+LLVideoPlayer.h"
#import "NSString+LLVideoPlayer.h"

@implementation NSURLResponse (LLVideoPlayer)

- (BOOL)ll_supportRange
{
    if (NO == [self isKindOfClass:[NSHTTPURLResponse class]]) {
        return NO;
    }
    return ((NSHTTPURLResponse *)self).allHeaderFields[@"Content-Range"] != nil;
}

- (NSInteger)ll_totalLength
{
    // Get total content length
    
    if (NO == [self isKindOfClass:[NSHTTPURLResponse class]]) {
        return [self expectedContentLength];
    }
    
    // For example: "Content-Range" = "bytes 57933824-57999359/65904318"
    NSString *contentRange = ((NSHTTPURLResponse *)self).allHeaderFields[@"Content-Range"];
    NSString *lengthString = [contentRange ll_decodeLengthFromContentRange];
    if (lengthString) {
        return [lengthString integerValue];
    }
    
    return [self expectedContentLength];
}

@end
