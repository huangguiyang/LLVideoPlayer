//
//  LLVideoPlayerBasicOperation.m
//  Pods
//
//  Created by mario on 2017/6/27.
//
//

#import "LLVideoPlayerBasicOperation.h"

@interface LLVideoPlayerBasicOperation ()

@property (nonatomic, getter = isFinished, readwrite)  BOOL finished;
@property (nonatomic, getter = isExecuting, readwrite) BOOL executing;

@end

@implementation LLVideoPlayerBasicOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (BOOL)isExecuting
{
    return _executing;
}

- (BOOL)isFinished
{
    return _finished;
}

- (void)setExecuting:(BOOL)executing
{
    if (executing != _executing) {
        [self willChangeValueForKey:@"isExecuting"];
        _executing = executing;
        [self didChangeValueForKey:@"isExecuting"];
    }
}

- (void)setFinished:(BOOL)finished
{
    if (finished != _finished) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = finished;
        [self didChangeValueForKey:@"isFinished"];
    }
}

@end
