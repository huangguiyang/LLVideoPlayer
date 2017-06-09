//
//  LLVideoPlayerCacheTask.m
//  Pods
//
//  Created by mario on 2017/6/9.
//
//

#import "LLVideoPlayerCacheTask.h"

@interface LLVideoPlayerCacheTask () {
    BOOL _cancel;
}

@end

@implementation LLVideoPlayerCacheTask

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile
                       userInfo:(NSDictionary *)userInfo
{
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        self.range = range;
        self.userInfo = userInfo;
        self.cacheFile = cacheFile;
    }
    return self;
}

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile
                       userInfo:(NSDictionary *)userInfo
{
    return [[self alloc] initWithRequest:loadingRequest range:range cacheFile:cacheFile userInfo:userInfo];
}

- (void)resume
{
    
}

- (void)cancel
{
    @synchronized (self) {
        _cancel = YES;
        if (self.completionBlock) {
            self.completionBlock(self, [NSError errorWithDomain:@"LLVideoPlayerCacheTask"
                                                           code:NSURLErrorCancelled
                                                       userInfo:nil]);
        }
    }
}

- (BOOL)isCancelled
{
    @synchronized (self) {
        return _cancel;
    }
}

@end
