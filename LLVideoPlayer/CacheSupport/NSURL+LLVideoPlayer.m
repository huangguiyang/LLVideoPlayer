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

- (void)setOriginalScheme:(NSString *)scheme
{
    objc_setAssociatedObject(self, &originalSchemeKey, scheme, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)originalScheme
{
    return objc_getAssociatedObject(self, &originalSchemeKey);
}

- (NSURL *)ll_customSchemeURL
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    NSURL *url = [components URL];
    url.originalScheme = self.scheme;
    return url;
}

- (NSURL *)ll_originalSchemeURL
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
    if (self.originalScheme) {
        components.scheme = self.originalScheme;
    }
    return [components URL];
}

@end
