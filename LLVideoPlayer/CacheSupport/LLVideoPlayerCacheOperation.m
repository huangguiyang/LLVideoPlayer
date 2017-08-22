//
//  LLVideoPlayerCacheOperation.m
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerCacheOperation.h"
#import "LLVideoPlayerCacheLocalTask.h"
#import "LLVideoPlayerCacheRemoteTask.h"
#import "LLVideoPlayerInternal.h"

@interface LLVideoPlayerCacheOperation () <LLVideoPlayerCacheTaskDelegate>
{
    NSInteger _cancels;
}

@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSMutableArray<LLVideoPlayerCacheTask *> *taskQueue;

@end

@implementation LLVideoPlayerCacheOperation

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        self.cacheFile = cacheFile;
    }
    return self;
}

+ (instancetype)operationWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                  cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    return [[self alloc] initWithLoadingRequest:loadingRequest cacheFile:cacheFile];
}

- (void)dealloc
{
    LLLog(@"dealloc %@", self);
}

- (void)resume
{
    LLLog(@"resume %@", self);
    @synchronized (self) {
        [self startOperation];
    }
}

- (void)cancel
{
    @synchronized (self) {
        NSArray *copyQueue = [NSArray arrayWithArray:self.taskQueue];
        for (LLVideoPlayerCacheTask *task in copyQueue) {
            [task cancel];
        }
    }
    LLLog(@"cancel %@", self);
}

#pragma mark - LLVideoPlayerCacheTaskDelegate

- (void)taskDidFinish:(LLVideoPlayerCacheTask *)task
{
    LLLog(@"[TASK FINISH] %@", task);
    @synchronized (self) {
        [self.taskQueue removeObject:task];
        if (self.taskQueue.count == 0) {
            if (_cancels == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(operationDidFinish:)]) {
                        [self.delegate operationDidFinish:self];
                    }
                });
            }
        } else {
            [self resumeNextTask];
        }
    }
}

- (void)task:(LLVideoPlayerCacheTask *)task didFailWithError:(NSError *)error
{
    LLLog(@"[TASK FAIL] %@, %@", task, error);
    @synchronized (self) {
        [self.taskQueue removeObject:task];
        if ([task isCancelled] || error.code == NSURLErrorCancelled) {
            _cancels++;
        } else {
            [self cancel];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(operation:didFailWithError:)]) {
                    [self.delegate operation:self didFailWithError:error];
                }
            });
        }
    }
}

#pragma mark - Private

- (void)resumeNextTask
{
    [[self.taskQueue firstObject] resume];
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
    
    self.taskQueue = [NSMutableArray arrayWithCapacity:4];
    
    [self mapOperationToTasksWithRange:range];
    [self.cacheFile tryResponseForLoadingRequest:self.loadingRequest withRange:range];
    [self resumeNextTask];
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
    
    task.delegate = self;
    [self.taskQueue addObject:task];
    
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
