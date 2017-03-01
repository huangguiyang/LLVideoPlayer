//
//  LLPlayerItemCacheTask.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLPlayerItemCacheTask.h"

@interface LLPlayerItemCacheTask ()

@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, assign, getter=isFinished) BOOL finished;

@end

@implementation LLPlayerItemCacheTask
@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithCacheFilePath:(LLPlayerItemCacheFile *)cacheFile loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range
{
    self = [super init];
    if (self) {
        _cacheFile = cacheFile;
        _loadingRequest = loadingRequest;
        _range = range;
    }
    return self;
}

- (void)main
{
    @autoreleasepool {
        [self setFinished:NO];
        [self setExecuting:YES];
        if (self.finishBlock) {
            self.finishBlock(self, nil);
        }
        [self setExecuting:NO];
        [self setFinished:YES];
    }
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

@end
