//
//  LLVideoPlayerCacheUtils.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN const NSRange LLInvalidRange;

@interface LLVideoPlayerCacheUtils : NSObject

+ (NSString *)cacheDirectoryPath;

@end

NS_INLINE BOOL LLValidByteRange(NSRange range)
{
    return range.location != NSNotFound || range.length > 0;
}

NS_INLINE BOOL LLValidFileRange(NSRange range)
{
    return range.location != NSNotFound && range.length > 0 && range.length != NSIntegerMax;
}

NS_INLINE BOOL LLRangeCanMerge(NSRange range1, NSRange range2)
{
    return NSMaxRange(range1) == range2.location || NSMaxRange(range2) == range1.location || NSIntersectionRange(range1, range2).length > 0;
}

FOUNDATION_EXTERN NSString *LLRangeToHTTPRangeHeader(NSRange range);
FOUNDATION_EXTERN NSString *LLRangeToHTTPRangeResponseHeader(NSRange range, NSUInteger length);
