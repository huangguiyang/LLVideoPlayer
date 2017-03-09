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
    if (NO == [components.scheme hasPrefix:@"streaming"]) {
        components.scheme = [NSString stringWithFormat:@"streaming%@", components.scheme];
    }
    return [components URL];
}

- (NSURL *)ll_originalSchemeURL
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
    if ([components.scheme hasPrefix:@"streaming"]) {
        components.scheme = [components.scheme substringFromIndex:@"streaming".length];
    }
    return [components URL];
}

@end
