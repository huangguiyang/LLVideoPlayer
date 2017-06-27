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

@interface LLVideoPlayerCacheOperation ()
{
    CFRunLoopRef _runLoop;
}

@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, assign) NSInteger cancels;

@end

@implementation LLVideoPlayerCacheOperation

- (void)dealloc
{
    [self.operationQueue removeObserver:self forKeyPath:@"operationCount"];
    [self.operationQueue cancelAllOperations];
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        self.cacheFile = cacheFile;
        self.operationQueue = [[NSOperationQueue alloc] init];
        [self.operationQueue setName:@"LLVideoPlayerCacheOperation-Tasks"];
        self.operationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        self.operationQueue.maxConcurrentOperationCount = 1;    // very important
        [self.operationQueue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:nil];
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
        @synchronized (self) {
            if ([self isCancelled]) {
                return;
            }
            
            [self setExecuting:YES];
            [self startOperation];
        }
        
        [self startRunLoop];
        
        [self setExecuting:NO];
        [self setFinished:YES];
        LLLog(@"operation complete: %p", self);
    }
}

- (void)cancel
{
    @synchronized (self) {
        [super cancel];
        [self.operationQueue cancelAllOperations];
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

- (void)finishOperationWithError:(NSError *)error
{
    if (error) {
        [self.loadingRequest finishLoadingWithError:error];
    } else {
        [self.loadingRequest finishLoading];
    }
    [self stopRunLoop];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"cancelled"]) {
        
        BOOL cancelled = [change[NSKeyValueChangeNewKey] boolValue];
        if (cancelled) {
            LLVideoPlayerCacheTask *task = (LLVideoPlayerCacheTask *)object;
            [task removeObserver:self forKeyPath:@"cancelled"];
            [task removeObserver:self forKeyPath:@"finished"];
            self.cancels++;
            LLLog(@"[CANCEL] %@", task);
        }
        
    } else if ([keyPath isEqualToString:@"finished"]) {
        
        BOOL finished = [change[NSKeyValueChangeNewKey] boolValue];
        if (finished) {
            LLVideoPlayerCacheTask *task = (LLVideoPlayerCacheTask *)object;
            [task removeObserver:self forKeyPath:@"cancelled"];
            [task removeObserver:self forKeyPath:@"finished"];
            
            if (task.error) {
                LLLog(@"[FAILED] %@", task);
                [self cancel];
                [self finishOperationWithError:task.error];
            } else {
                // OK
                LLLog(@"[COMPLETE] %@", task);
            }
        }
        
    } else if ([keyPath isEqualToString:@"operationCount"]) {
        
        NSInteger operationCount = [change[NSKeyValueChangeNewKey] integerValue];
        if (operationCount == 0) {
            if (self.cancels == 0) {
                LLLog(@"[FINISH] %@", self);
                [self finishOperationWithError:nil];
            }
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Operations

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
    
    self.operationQueue.suspended = YES;
    
    [self mapOperationToTasksWithRange:range];
    [self.cacheFile tryResponseForLoadingRequest:self.loadingRequest withRange:range];
    
    self.operationQueue.suspended = NO;
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

    [task addObserver:self forKeyPath:@"finished" options:NSKeyValueObservingOptionNew context:nil];
    [task addObserver:self forKeyPath:@"cancelled" options:NSKeyValueObservingOptionNew context:nil];
    [self.operationQueue addOperation:task];
    
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

@end
