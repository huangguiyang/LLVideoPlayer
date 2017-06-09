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
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "LLVideoPlayerCacheLocalTask.h"
#import "LLVideoPlayerCacheRemoteTask.h"

@interface LLVideoPlayerCacheOperation () {
    CFRunLoopRef _runloop;
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
    _runloop = CFRunLoopGetCurrent();
    CFRunLoopRun();
}

- (void)stopRunLoop
{
    if (_runloop) {
        CFRunLoopStop(_runloop);
        _runloop = NULL;
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
    
    LLVideoPlayerCacheRemoteTask *task = [LLVideoPlayerCacheRemoteTask taskWithRequest:self.loadingRequest range:range cacheFile:self.cacheFile userInfo:nil];
    
    __weak typeof(self) wself = self;
    [task setCompletionBlock:^(LLVideoPlayerCacheTask *task, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
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
    }];
    
    [self.tasks addObject:task];
    [task resume];
    
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

@end
