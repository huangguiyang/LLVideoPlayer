//
//  LLVideoPlayerCacheOperation.m
//  Pods
//
//  Created by mario on 2017/6/8.
//
//

#import "LLVideoPlayerCacheOperation.h"
#import "LLVideoPlayerInternal.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "LLVideoPlayerCacheLocalTask.h"
#import "LLVideoPlayerCacheRemoteTask.h"

@interface LLVideoPlayerCacheOperation () <LLVideoPlayerCacheTaskDelegate>
{
    CFRunLoopRef _runLoop;
}

@property (nonatomic, getter = isFinished, readwrite)  BOOL finished;
@property (nonatomic, getter = isExecuting, readwrite) BOOL executing;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSMutableArray *tasks;

@end

@implementation LLVideoPlayerCacheOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (void)dealloc
{
    LLLog(@"operation dealloc: %p", self);
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        self.cacheFile = cacheFile;
        self.tasks = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)operationWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                  cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    return [[self alloc] initWithLoadingRequest:loadingRequest cacheFile:cacheFile];
}

- (void)main
{
    LLLog(@"operation main: %@, %p", [NSThread currentThread], self);
    
    @autoreleasepool {
        if ([self isCancelled]) {
            [self completeOperation];
            return;
        }
        
        self.executing = YES;
        [self startOperation];
        [self completeOperation];
    }
}

- (void)completeOperation
{
    self.executing = NO;
    self.finished = YES;
    LLLog(@"operation complete: %p", self);
}

#pragma mark - Cancel

- (void)cancel
{
    for (LLVideoPlayerCacheTask *task in self.tasks) {
        [task cancel];
    }
    [self.tasks removeAllObjects];
    [super cancel];
    LLLog(@"operation cancelled: %p", self);
}

#pragma mark - Executing && Finished

- (BOOL)isExecuting
{
    @synchronized (self) {
        return _executing;
    }
}

- (BOOL)isFinished
{
    @synchronized (self) {
        return _finished;
    }
}

- (void)setExecuting:(BOOL)executing
{
    if (executing != _executing) {
        [self willChangeValueForKey:@"isExecuting"];
        @synchronized (self) {
            _executing = executing;
        }
        [self didChangeValueForKey:@"isExecuting"];
    }
}

- (void)setFinished:(BOOL)finished
{
    if (finished != _finished) {
        [self willChangeValueForKey:@"isFinished"];
        @synchronized (self) {
            _finished = finished;
        }
        [self didChangeValueForKey:@"isFinished"];
    }
}

#pragma mark - RunLoop

- (void)startRunLoop
{
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    _runLoop = runloop.getCFRunLoop;
    [runloop run];
}

- (void)stopRunLoop
{
    if (_runLoop) {
        CFRunLoopStop(_runLoop);
        _runLoop = nil;
    }
}

#pragma mark - Connection

- (void)startOperation
{
    // range
    NSRange range;
    if ([self.loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] &&
        self.loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
        range = NSMakeRange(self.loadingRequest.dataRequest.requestedOffset, NSIntegerMax);
    } else {
        range = NSMakeRange(self.loadingRequest.dataRequest.requestedOffset,
                            self.loadingRequest.dataRequest.requestedLength);
    }
    
    [self mapOperationToTasksWithRange:range];
    
    for (LLVideoPlayerCacheTask *task in self.tasks) {
        [task resume];
    }
    
    [self startRunLoop];
}

- (void)finishOperationWithError:(NSError *)error
{
    if (error) {
        [self.loadingRequest finishLoadingWithError:error];
    } else {
        [self.loadingRequest finishLoading];
    }
    
    [self stopRunLoop];
}

#pragma mark - LLVideoPlayerCacheTaskDelegate

- (void)task:(LLVideoPlayerCacheTask *)task didCompleteWithError:(NSError *)error
{
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wself) self = wself;
        LLLog(@"[COMPLETE] task %@, error: %@", task, error);
        [self.tasks removeObject:task];
        
        if ([self isCancelled] || error.code == NSUserCancelledError) {
            if (self.tasks.count == 0) {
                [self stopRunLoop];
            }
            return;
        }
        
        if (error) {
            [self cancel];
            [self finishOperationWithError:error];
            return;
        }
        
        if (self.tasks.count == 0) {
            [self finishOperationWithError:error];
        }
    });
}

#pragma mark - Private

- (void)addTaskWithRange:(NSRange)range fromCache:(BOOL)fromCache
{
    LLVideoPlayerCacheTask *task;
    
    if (fromCache) {
        task = [LLVideoPlayerCacheLocalTask taskWithRequest:self.loadingRequest range:range cacheFile:self.cacheFile];
    } else {
        task = [LLVideoPlayerCacheRemoteTask taskWithRequest:self.loadingRequest range:range cacheFile:self.cacheFile];
    }
    
    [task setDelegate:self];
    [self.tasks addObject:task];
    
    LLLog(@"[ADD] %@ with range: %@", NSStringFromClass([task class]), NSStringFromRange(task.range));
}

- (void)mapOperationToTasksWithRange:(NSRange)requestRange
{
    [self.tasks removeAllObjects];
    
    [self.cacheFile tryResponseForLoadingRequest:self.loadingRequest withRange:requestRange];
    
    NSInteger start = requestRange.location;
    NSInteger end = requestRange.length == NSIntegerMax ? NSIntegerMax : NSMaxRange(requestRange);
    
    NSArray<NSValue *> *ranges = [self.cacheFile ranges];
    for (NSValue *value in ranges) {
        NSRange range = [value rangeValue];
        
        if (start >= NSMaxRange(range)) {
            continue;
        }
        
        if (start < range.location) {
            [self addTaskWithRange:NSMakeRange(start, range.location - start) fromCache:NO];
            start = range.location;
        }
        
        // in range
        NSAssert(NSLocationInRange(start, range), @"Oops!!!");
        
        if (end <= NSMaxRange(range)) {
            [self addTaskWithRange:NSMakeRange(start, end - start) fromCache:YES];
            start = end;
            break;
        }
        
        [self addTaskWithRange:NSMakeRange(start, NSMaxRange(range) - start) fromCache:YES];
        start = NSMaxRange(range);
    }
    
    if (end > start && (self.cacheFile.fileLength == 0 || start < self.cacheFile.fileLength)) {
        [self addTaskWithRange:NSMakeRange(start, end - start) fromCache:NO];
    }
}

@end
