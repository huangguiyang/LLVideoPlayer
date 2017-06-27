//
//  LLVideoPlayerCacheTask.m
//  Pods
//
//  Created by mario on 2017/6/23.
//
//

#import "LLVideoPlayerCacheTask.h"
#import "LLVideoPlayerInternal.h"

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

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@<%p>: %@",
            NSStringFromClass([self class]), self, NSStringFromRange(self.range)];
}

@end
