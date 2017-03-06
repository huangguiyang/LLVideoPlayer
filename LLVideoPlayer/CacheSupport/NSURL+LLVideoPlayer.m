//
//  NSURL+LLVideoPlayer.m
//  Pods
//
//  Created by mario on 2017/2/22.
//
//

#import "NSURL+LLVideoPlayer.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

static char originalSchemeKey;

@implementation NSURL (LLVideoPlayer)

- (NSURL *)ll_customSchemeURL
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
    NSRange range = [components.scheme rangeOfString:@"streaming" options:NSBackwardsSearch];
    if (range.location == NSNotFound) {
        components.scheme = [NSString stringWithFormat:@"%@streaming", components.scheme];
    }
    return [components URL];
}

- (NSURL *)ll_originalSchemeURL
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
    NSRange range = [components.scheme rangeOfString:@"streaming" options:NSBackwardsSearch];
    if (range.location != NSNotFound) {
        components.scheme = [components.scheme substringToIndex:range.location];
    }
    return [components URL];
}

@end
