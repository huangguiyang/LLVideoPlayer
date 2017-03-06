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

FOUNDATION_EXTERN BOOL LLValidByteRange(NSRange range);
FOUNDATION_EXTERN BOOL LLValidFileRange(NSRange range);
FOUNDATION_EXTERN BOOL LLRangeCanMerge(NSRange range1, NSRange range2);
FOUNDATION_EXTERN NSString *LLRangeToHTTPRangeHeader(NSRange range);
FOUNDATION_EXTERN NSString *LLRangeToHTTPRangeResponseHeader(NSRange range, NSUInteger length);
