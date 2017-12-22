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

static NSString *const kCustomSchemePrefix = @"ll-";

@implementation NSURL (LLVideoPlayer)

- (NSURL *)ll_customSchemeURL
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
    if (NO == [components.scheme hasPrefix:kCustomSchemePrefix]) {
        components.scheme = [NSString stringWithFormat:@"%@%@", kCustomSchemePrefix, components.scheme];
    }
    return [components URL];
}

- (NSURL *)ll_originalSchemeURL
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
    if ([components.scheme hasPrefix:kCustomSchemePrefix]) {
        components.scheme = [components.scheme substringFromIndex:kCustomSchemePrefix.length];
    }
    return [components URL];
}

- (BOOL)ll_m3u8
{
    return [[[self pathExtension] lowercaseString] isEqualToString:@"m3u8"];
}

@end
