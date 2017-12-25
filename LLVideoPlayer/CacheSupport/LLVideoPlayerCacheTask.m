//
//  LLVideoPlayerCacheTask.m
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerCacheTask.h"

@interface LLVideoPlayerCacheTask ()
{
    BOOL _cancel;
}

@end

@implementation LLVideoPlayerCacheTask

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        self.range = range;
        self.cacheFile = cacheFile;
    }
    return self;
}

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                      cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    return [[self alloc] initWithRequest:loadingRequest range:range cacheFile:cacheFile];
}

- (void)dealloc
{
}

- (void)resume
{
}

- (void)cancel
{
    @synchronized (self) {
        if (NO == _cancel) {
            _cancel = YES;
            if ([self.delegate respondsToSelector:@selector(task:didFailWithError:)]) {
                [self.delegate task:self didFailWithError:
                 [NSError errorWithDomain:@"LLVideoPlayerCacheTask" code:NSURLErrorCancelled userInfo:nil]];
            }
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
