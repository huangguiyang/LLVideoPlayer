//
//  LLVideoPlayerCacheTask.m
//  Pods
//
//  Created by mario on 2017/6/9.
//
//

#import "LLVideoPlayerCacheTask.h"

@implementation LLVideoPlayerCacheTask

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range userInfo:(NSDictionary *)userInfo
{
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        self.range = range;
        self.userInfo = userInfo;
    }
    return self;
}

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range userInfo:(NSDictionary *)userInfo
{
    return [[self alloc] initWithRequest:loadingRequest range:range userInfo:userInfo];
}

- (void)resume
{
    
}

- (void)cancel
{
    if (self.completionBlock) {
        self.completionBlock(self, [NSError errorWithDomain:@"LLVideoPlayerCacheTask"
                                                       code:NSURLErrorCancelled
                                                   userInfo:nil]);
    }
}

- (void)complete
{
    
}

@end
