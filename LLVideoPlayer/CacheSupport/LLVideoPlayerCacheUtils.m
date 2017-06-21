//
//  LLVideoPlayerCacheUtils.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheUtils.h"

const NSRange LLInvalidRange = { NSNotFound, 0 };

NSString *LLRangeToHTTPRangeHeader(NSRange range)
{
    if (LLValidByteRange(range)) {
        if (range.location == NSNotFound) {
            return [NSString stringWithFormat:@"bytes=-%tu", range.length];
        } else if (range.length == NSIntegerMax) {
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
        } else if (range.length == NSIntegerMax) {
            start = length - range.length;
            end = start + range.length - 1;
        }
        
        return [NSString stringWithFormat:@"bytes %tu-%tu/%tu", start, end, length];
    } else {
        return nil;
    }
}

NSString *LLLoadingRequestToString(AVAssetResourceLoadingRequest *loadingRequest)
{
    if ([loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)]) {
        return [NSString stringWithFormat:@"<%p: %@, ToEnd: %@>",
                loadingRequest,
                NSStringFromRange(NSMakeRange(loadingRequest.dataRequest.requestedOffset,
                                              loadingRequest.dataRequest.requestedLength)),
                [loadingRequest.dataRequest requestsAllDataToEndOfResource] ? @"YES" : @"NO"];
    } else {
        return [NSString stringWithFormat:@"<%p: %@>",
                loadingRequest,
                NSStringFromRange(NSMakeRange(loadingRequest.dataRequest.requestedOffset,
                                              loadingRequest.dataRequest.requestedLength))];
    }
}
