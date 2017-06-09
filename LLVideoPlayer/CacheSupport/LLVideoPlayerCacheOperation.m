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
    LLLog(@"LLVideoPlayerCacheOperation dealloc: %p", self);
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
    LLLog(@"operation main: %p", self);
    
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
    LLLog(@"operation will complete... %p", self);
    self.executing = NO;
    self.finished = YES;
    LLLog(@"operation complete: %p", self);
}

#pragma mark - Cancel

- (void)cancel
{
    LLLog(@"operation will cancel... %p", self);
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
    
    LLVideoPlayerCacheRemoteTask *task = [LLVideoPlayerCacheRemoteTask taskWithRequest:self.loadingRequest range:range userInfo:nil];
    
    __weak typeof(self) wself = self;
    [task setDidReceiveResponseBlock:^(LLVideoPlayerCacheTask *task, NSURLResponse *response){
        __strong typeof(wself) self = wself;
        [self.loadingRequest ll_fillContentInformation:response];
    }];
    [task setCompletionBlock:^(LLVideoPlayerCacheTask *task, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            
            if ([self isCancelled] || error.code == NSUserCancelledError) {
                return;
            }
            
            [self.tasks removeObject:task];
            
            if (self.tasks.count == 0) {
                if (nil == error) {
                    [self.loadingRequest finishLoading];
                } else {
                    [self.loadingRequest finishLoadingWithError:error];
                }
            }
        });
    }];
    [self.tasks addObject:task];
    [task resume];
    
    [self startRunLoop];
}

@end
