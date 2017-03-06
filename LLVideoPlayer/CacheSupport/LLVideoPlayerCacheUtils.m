//
//  LLVideoPlayerCacheUtils.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheUtils.h"

const NSRange LLInvalidRange = { NSNotFound, 0 };

@implementation LLVideoPlayerCacheUtils

+ (NSString *)cacheDirectoryPath
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [cache stringByAppendingPathComponent:@"com.ll.vplayer"];
    return dir;
}

@end

BOOL LLValidByteRange(NSRange range)
{
    return range.location != NSNotFound || range.length > 0;
}

BOOL LLValidFileRange(NSRange range)
{
    return range.location != NSNotFound && range.length > 0 && range.length != NSUIntegerMax;
}

BOOL LLRangeCanMerge(NSRange range1, NSRange range2)
{
    return NSMaxRange(range1) == range2.location || NSMaxRange(range2) == range1.location || NSIntersectionRange(range1, range2).length > 0;
}

NSString *LLRangeToHTTPRangeHeader(NSRange range)
{
    if (LLValidByteRange(range)) {
        if (range.location == NSNotFound) {
            return [NSString stringWithFormat:@"bytes=-%tu", range.length];
        } else if (range.length == NSUIntegerMax) {
            return [NSString stringWithFormat:@"bytes=%tu-", range.location];
        } else {
            return [NSString stringWithFormat:@"bytes=%tu-%tu", range.location, NSMaxRange(range) - 1];
        }
    } else {
        return nil;
    }
}

NSString *LLRangeToHTTPRangeResponseHeader(NSRange range, NSUInteger length)
{
    if (LLValidByteRange(range)) {
        NSUInteger start = range.location;
        NSUInteger end = NSMaxRange(range) - 1;
        if (range.location == NSNotFound) {
            start = range.location;
        } else if (range.length == NSUIntegerMax) {
            start = length - range.length;
            end = start + range.length - 1;
        }
        
        return [NSString stringWithFormat:@"bytes %tu-%tu/%tu", start, end, length];
    } else {
        return nil;
    }
}
