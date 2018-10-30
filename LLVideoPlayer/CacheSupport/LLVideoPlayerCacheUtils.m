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

NSRange LLHTTPRangeHeaderToRange(NSString *rangeStr)
{
    if (NO == [rangeStr hasPrefix:@"bytes="]) {
        return NSMakeRange(0, 0);
    }
    
    NSString *sub = [rangeStr substringFromIndex:6];
    if ([sub hasPrefix:@"-"]) {
        NSInteger length = [[sub substringFromIndex:1] integerValue];
        return NSMakeRange(NSNotFound, length);
    } else if ([sub hasSuffix:@"-"]) {
        NSInteger loc = [[sub substringToIndex:sub.length-1] integerValue];
        return NSMakeRange(loc, NSIntegerMax);
    } else {
        NSArray *components = [sub componentsSeparatedByString:@"-"];
        if (components.count != 2) {
            return NSMakeRange(0, 0);
        }
        NSInteger start = [components[0] integerValue];
        NSInteger end = [components[1] integerValue];
        
        return NSMakeRange(start, end - start + 1);
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

NSString *LLValueForHTTPHeaderField(NSDictionary *headers, NSString *key)
{
    NSString *value;
    
    if (nil == headers || nil == key) return nil;
    value = [headers objectForKey:key];
    if (value) return value;
    value = [headers objectForKey:[key lowercaseString]];
    if (value) return value;
    value = [headers objectForKey:[key capitalizedString]];
    if (value) return value;
    
    return nil;
}

void ll_run_on_non_ui_thread(dispatch_block_t block)
{
    if ([NSThread isMainThread]) {
        dispatch_async(dispatch_get_global_queue(0, 0), block);
    } else {
        block();
    }
}
