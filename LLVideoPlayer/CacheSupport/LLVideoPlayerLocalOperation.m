//
//  LLVideoPlayerLocalOperation.m
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerLocalOperation.h"
#import "LLVideoPlayerCacheUtils.h"

@interface LLVideoPlayerLocalOperation ()

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;

@end

@implementation LLVideoPlayerLocalOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@", NSStringFromClass(self.class), self, [self.request valueForHTTPHeaderField:@"Range"]];
}

- (instancetype)initWithRequest:(NSURLRequest *)request cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        _request = request;
        _cacheFile = cacheFile;
    }
    return self;
}

- (void)main
{
    @autoreleasepool {
        @synchronized (self) {
            if ([self isCancelled]) {
                [self finish];
                return;
            }
            
            self.executing = YES;
            
            NSError *error = nil;
            NSString *rangeStr = [self.request valueForHTTPHeaderField:@"Range"];
            NSRange range = LLHTTPRangeHeaderToRange(rangeStr);
            NSData *data = [self.cacheFile dataWithRange:range];
            [self finish];
            
            if (data) {
                if ([self.delegate respondsToSelector:@selector(operation:didReceiveData:)]) {
                    [self.delegate operation:self didReceiveData:data];
                }
            } else {
                // data == nil
                error = [NSError errorWithDomain:NSURLErrorDomain code:404 userInfo:nil];
            }
            
            if ([self.delegate respondsToSelector:@selector(operation:didCompleteWithError:)]) {
                [self.delegate operation:self didCompleteWithError:error];
            }
        }
    }
}

- (void)cancel
{
    @synchronized (self) {
        if ([self isFinished] || [self isCancelled]) {
            return;
        }
        [super cancel];
        if ([self isExecuting]) {
            [self finish];
        }
        
        if ([self.delegate respondsToSelector:@selector(operation:didCompleteWithError:)]) {
            [self.delegate operation:self didCompleteWithError:
             [NSError errorWithDomain:@"LLVideoPlayerCacheTask" code:NSURLErrorCancelled userInfo:nil]];
        }
    }
}

- (void)finish
{
    self.executing = NO;
    self.finished = YES;
}

- (void)setFinished:(BOOL)finished
{
    if (_finished != finished) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = finished;
        [self didChangeValueForKey:@"isFinished"];
    }
}

- (void)setExecuting:(BOOL)executing
{
    if (_executing != executing) {
        [self willChangeValueForKey:@"isExecuting"];
        _executing = executing;
        [self didChangeValueForKey:@"isExecuting"];
    }
}

@end
