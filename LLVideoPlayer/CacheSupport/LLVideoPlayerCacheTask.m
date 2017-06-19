//
//  LLVideoPlayerCacheTask.m
//  Pods
//
//  Created by mario on 2017/6/9.
//
//

#import "LLVideoPlayerCacheTask.h"
#import "LLVideoPlayerInternal.h"

@interface LLVideoPlayerCacheTask () {
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

- (void)resume
{
}

- (void)cancel
{
    @synchronized (self) {
        _cancel = YES;
        if ([self.delegate respondsToSelector:@selector(task:didCompleteWithError:)]) {
            [self.delegate task:self didCompleteWithError:[NSError errorWithDomain:@"LLVideoPlayerCacheTask"
                                                                              code:NSURLErrorCancelled
                                                                          userInfo:nil]];
        }
    }
}

- (BOOL)isCancelled
{
    @synchronized (self) {
        return _cancel;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@<%p>: %@",
            NSStringFromClass([self class]), self, NSStringFromRange(self.range)];
}

@end
