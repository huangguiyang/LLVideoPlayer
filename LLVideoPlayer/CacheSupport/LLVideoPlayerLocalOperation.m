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
        NSData *data = nil;
        NSError *error = nil;
        
        @synchronized (self) {
            if ([self isCancelled]) {
                [self finish];
                return;
            }
            
            self.executing = YES;
            
            NSString *rangeStr = [self.request valueForHTTPHeaderField:@"Range"];
            NSRange range = LLHTTPRangeHeaderToRange(rangeStr);
            data = [self.cacheFile dataWithRange:range error:&error];
            [self finish];
        }
        
        if (nil == error) {
            if ([self.delegate respondsToSelector:@selector(operation:didReceiveData:)]) {
                [self.delegate operation:self didReceiveData:data];
            }
            if ([self.delegate respondsToSelector:@selector(operationDidFinish:)]) {
                [self.delegate operationDidFinish:self];
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(operation:didFailWithError:)]) {
                [self.delegate operation:self didFailWithError:error];
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
            self.executing = NO;
        }
        if (NO == [self isFinished]) {
            self.finished = YES;
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(operation:didFailWithError:)]) {
        [self.delegate operation:self didFailWithError:
         [NSError errorWithDomain:@"LLVideoPlayerCacheTask" code:NSURLErrorCancelled userInfo:nil]];
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
