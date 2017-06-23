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
#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "LLVideoPlayerCacheRemoteTask.h"
#import "LLVideoPlayerCacheLocalTask.h"

@interface LLVideoPlayerCacheOperation () <LLVideoPlayerCacheTaskDelegate>
{
    CFRunLoopRef _runLoop;
    NSThread *_operationThread;
}

@property (nonatomic, getter = isFinished, readwrite)  BOOL finished;
@property (nonatomic, getter = isExecuting, readwrite) BOOL executing;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSMutableArray<LLVideoPlayerCacheTask *> *tasks;

@end

@implementation LLVideoPlayerCacheOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

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

#pragma mark - Start/Cancel/Main

- (void)main
{
    LLLog(@"operation main: %@: %@", [NSThread currentThread], LLLoadingRequestToString(self.loadingRequest));
    
    @autoreleasepool {
        if ([self isCancelled]) {
            return;
        }
        
        @synchronized (self) {
            _operationThread = [NSThread currentThread];
            self.executing = YES;
            [self startOperation];
        }
        
        [self startRunLoop];
        self.executing = NO;
        self.finished = YES;
        LLLog(@"operation complete: %p", self);
    }
}

- (void)cancel
{
    [super cancel];
    
    @synchronized (self) {
        NSArray *tasks = [NSArray arrayWithArray:self.tasks];
        for (LLVideoPlayerCacheTask *task in tasks) {
            [task cancel];
        }
    }
    LLLog(@"operation cancelled: %p", self);
}

- (void)startRunLoop
{
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    _runLoop = runloop.getCFRunLoop;
    CFRunLoopRun();
}

- (void)stopRunLoop
{
    if (_runLoop) {
        CFRunLoopStop(_runLoop);
        _runLoop = NULL;
    }
}

#pragma mark - Operations

- (void)startNextTask
{
    if (self.tasks.count > 0) {
        [[self.tasks firstObject] resume];
    } else {
        // finish operation
        [self finishOperationWithError:nil];
    }
}

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
    
    [self.tasks removeAllObjects];
    [self mapOperationToTasksWithRange:range];
    
    [self.cacheFile tryResponseForLoadingRequest:self.loadingRequest withRange:range];
    [self startNextTask];
}

- (void)finishOperationWithError:(NSError *)error
{
    LLLog(@"[FINISH] %@, error: %@", LLLoadingRequestToString(self.loadingRequest), error);
    if (error) {
        [self.loadingRequest finishLoadingWithError:error];
    } else {
        [self.loadingRequest finishLoading];
    }
    
    [self stopRunLoop];
}

- (LLVideoPlayerCacheTask *)addTaskWithRange:(NSRange)range fromCache:(BOOL)fromCache
{
    LLVideoPlayerCacheTask *task;
    
    if (fromCache) {
        task = [LLVideoPlayerCacheLocalTask taskWithRequest:self.loadingRequest range:range
                                                  cacheFile:self.cacheFile];
    } else {
        task = [LLVideoPlayerCacheRemoteTask taskWithRequest:self.loadingRequest range:range
                                                   cacheFile:self.cacheFile];
    }
    
    [task setDelegate:self];
    [self.tasks addObject:task];
    
    LLLog(@"[ADD] %@", task);
    
    return task;
}

- (void)mapOperationToTasksWithRange:(NSRange)requestRange
{
    NSInteger start = requestRange.location;
    NSInteger end = requestRange.length == NSIntegerMax ? NSIntegerMax : NSMaxRange(requestRange);
    
    NSArray<NSValue *> *ranges = [self.cacheFile cachedRanges];
    for (NSValue *value in ranges) {
        NSRange range = [value rangeValue];
        
        if (start >= NSMaxRange(range)) {
            continue;
        }
        
        if (start < range.location) {
            NSInteger cacheEnd = MIN(range.location, end);
            [self addTaskWithRange:NSMakeRange(start, cacheEnd - start) fromCache:NO];
            start = cacheEnd;
            if (start == end) {
                break;
            }
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
        if (end == NSIntegerMax) {
            [self addTaskWithRange:NSMakeRange(start, NSIntegerMax) fromCache:NO];
        } else {
            [self addTaskWithRange:NSMakeRange(start, end - start) fromCache:NO];
        }
    }
}

- (void)handleTaskDidComplete:(NSDictionary *)params
{
    LLVideoPlayerCacheTask *task = params[@"task"];
    NSError *error = params[@"error"];
    
    [self.tasks removeObject:task];
    
    if ([self isCancelled] || error.code == NSURLErrorCancelled) {
        LLLog(@"[CANCEL] %@", task);
        if (self.tasks.count == 0) {
            [self stopRunLoop];
        }
        return;
    }
    
    if (error) {
        LLLog(@"[FAILED] %@", task);
        [self cancel];
        [self finishOperationWithError:error];
        return;
    }
    
    LLLog(@"[COMPLETE] %@", task);
    [self startNextTask];
}

#pragma mark - LLVideoPlayerCacheTaskDelegate

- (void)task:(LLVideoPlayerCacheTask *)task didCompleteWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"task"] = task;
        if (error) {
            params[@"error"] = error;
        }
        
        [self performSelector:@selector(handleTaskDidComplete:)
                     onThread:_operationThread withObject:params waitUntilDone:NO];
    });
}

@end
