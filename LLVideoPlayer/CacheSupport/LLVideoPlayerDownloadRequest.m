//
//  LLVideoPlayerDownloadRequest.m
//  LLVideoPlayer
//
//  Created by mario on 2018/10/26.
//

#import "LLVideoPlayerDownloadRequest.h"
#import "LLVideoPlayerRemoteOperation.h"
#import "LLVideoPlayerCacheUtils.h"

@interface LLVideoPlayerDownloadRequest () <LLVideoPlayerOperationDelegate>

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSMutableArray *taskQueue;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSError *error;

@end

@implementation LLVideoPlayerDownloadRequest

- (instancetype)initWithRequest:(NSURLRequest *)request cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        _request = request;
        _cacheFile = cacheFile;
        _operationQueue = [[NSOperationQueue alloc] init];
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)resume
{
    [self.lock lock];
    [self startOperation];
    [self.lock unlock];
}

- (void)cancel
{
    [self.lock lock];
    NSArray *copyQueue = [NSArray arrayWithArray:self.taskQueue];
    for (NSOperation *operation in copyQueue) {
        [operation cancel];
    }
    [self.lock unlock];
}

- (void)startOperation
{
    NSString *rangeStr = [self.request valueForHTTPHeaderField:@"Range"];
    NSRange requestRange = LLHTTPRangeHeaderToRange(rangeStr);
    if (requestRange.length == 0) {
        requestRange = NSMakeRange(0, NSIntegerMax);
    }
    
    self.taskQueue = [NSMutableArray arrayWithCapacity:4];
    
    [self.cacheFile enumerateRangesWithRequestRange:requestRange usingBlock:^(NSRange range, BOOL cached) {
        if (NO == cached) {
            [self addTaskWithRange:range];
        }
    }];
    
    // resume task
    if (self.taskQueue.count > 0) {
        for (NSOperation *operation in self.taskQueue) {
            [self.operationQueue addOperation:operation];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completedBlock) {
                self.completedBlock(nil);
            }
        });
    }
}

- (void)addTaskWithRange:(NSRange)range
{
    NSMutableURLRequest *request = [self.request mutableCopy];
    NSString *rangeStr = LLRangeToHTTPRangeHeader(range);
    if (rangeStr) {
        [request setValue:rangeStr forHTTPHeaderField:@"Range"];
    }
    LLVideoPlayerRemoteOperation *task = [[LLVideoPlayerRemoteOperation alloc] initWithRequest:request cacheFile:self.cacheFile];
    [task setDelegate:self];
    
    [self.taskQueue addObject:task];
}

#pragma mark - LLVideoPlayerOperationDelegate

- (void)operation:(NSOperation *)operation didCompleteWithError:(NSError *)error
{
    [self.lock lock];
    [self.taskQueue removeObject:operation];
    if (error && nil == self.error) {
        self.error = error;
    }
    if (self.taskQueue.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completedBlock) {
                self.completedBlock(self.error);
            }
        });
    }
    [self.lock unlock];
}

- (void)operation:(NSOperation *)operation didReceiveData:(NSData *)data
{
    
}

- (void)operation:(NSOperation *)operation didReceiveResponse:(NSURLResponse *)response
{
    
}

@end
