//
//  LLVideoPlayerLoadingRequest.m
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerLoadingRequest.h"
#import "LLVideoPlayerLocalOperation.h"
#import "LLVideoPlayerRemoteOperation.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"

@interface LLVideoPlayerLoadingRequest () <LLVideoPlayerOperationDelegate>

@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSMutableArray<NSOperation *> *taskQueue;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, assign) NSInteger cancels;
@property (nonatomic, strong) NSURLResponse *response;

@end

@implementation LLVideoPlayerLoadingRequest

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        _loadingRequest = loadingRequest;
        _cacheFile = cacheFile;
        _lock = [[NSRecursiveLock alloc] init];
        _operationQueue = [NSOperationQueue new];
        _operationQueue.maxConcurrentOperationCount = 1;    // serial queue
    }
    return self;
}

- (void)resume
{
    [_lock lock];
    [self startOperation];
    [_lock unlock];
}

- (void)cancel
{
    [_lock lock];
    NSArray *copyQueue = [NSArray arrayWithArray:self.taskQueue];
    for (NSOperation *operation in copyQueue) {
        [operation cancel];
    }
    [_lock unlock];
}

#pragma mark - LLVideoPlayerCacheTaskDelegate

- (void)operationDidFinish:(NSOperation *)task
{
    [_lock lock];
    [self.taskQueue removeObject:task];
    if (self.taskQueue.count == 0 && self.cancels == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(requestDidFinish:)]) {
                [self.delegate requestDidFinish:self];
            }
        });
    }
    [_lock unlock];
}

- (void)operation:(NSOperation *)task didFailWithError:(NSError *)error
{
    [_lock lock];
    [self.taskQueue removeObject:task];
    if ([task isCancelled] || error.code == NSURLErrorCancelled) {
        self.cancels++;
    } else {
        [self cancel];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(request:didFailWithError:)]) {
                [self.delegate request:self didFailWithError:error];
            }
        });
    }
    [_lock unlock];
}

- (void)operation:(NSOperation *)operation didReceiveResponse:(NSURLResponse *)response
{
    [self tryResponse:response];
}

- (void)operation:(NSOperation *)operation didReceiveData:(NSData *)data
{
    [self.loadingRequest.dataRequest respondWithData:data];
}

#pragma mark - Private

- (void)tryResponse:(NSURLResponse *)response
{
    if (nil == _response && response) {
        _response = response;
        [self.loadingRequest ll_fillContentInformation:response];
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
    
    self.taskQueue = [NSMutableArray arrayWithCapacity:4];
    
    [self mapOperationToTasksWithRange:range];
    NSURLResponse *response = [self.cacheFile constructURLResponseForURL:self.loadingRequest.request.URL andRange:range];
    [self tryResponse:response];
    
    // resume task
    for (NSOperation *operation in self.taskQueue) {
        [self.operationQueue addOperation:operation];
    }
}

- (void)addTaskWithRange:(NSRange)range fromCache:(BOOL)fromCache
{
    NSOperation *task;
    
    NSMutableURLRequest *request = [self.loadingRequest.request mutableCopy];
    request.URL = [self.loadingRequest.request.URL ll_originalSchemeURL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData; // very important
    NSString *rangeStr = LLRangeToHTTPRangeHeader(range);
    if (rangeStr) {
        [request setValue:rangeStr forHTTPHeaderField:@"Range"];
    }
    
    if (fromCache) {
        task = [[LLVideoPlayerLocalOperation alloc] initWithRequest:request cacheFile:self.cacheFile];
        [(LLVideoPlayerLocalOperation *)task setDelegate:self];
    } else {
        task = [[LLVideoPlayerRemoteOperation alloc] initWithRequest:request cacheFile:self.cacheFile session:nil options:0];
        [(LLVideoPlayerRemoteOperation *)task setDelegate:self];
    }
    
    [self.taskQueue addObject:task];
}

- (void)mapOperationToTasksWithRange:(NSRange)requestRange
{
    [self.cacheFile enumerateRangesWithRequestRange:requestRange usingBlock:^(NSRange range, BOOL cached) {
        [self addTaskWithRange:range fromCache:cached];
    }];
}

@end
