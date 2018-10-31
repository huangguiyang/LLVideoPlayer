//
//  LLVideoPlayerDownloader.m
//  LLVideoPlayer
//
//  Created by mario on 2018/10/26.
//

#import "LLVideoPlayerDownloader.h"
#import "LLVideoPlayerCacheManager.h"
#import "LLVideoPlayerDownloadRequest.h"
#import "LLVideoPlayerCacheUtils.h"

#define kDefaultBytesLimit  (1 << 20)
#define kDefaultConcurrentCount 6

@interface LLVideoPlayerDownloader ()

@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, weak) LLVideoPlayerCacheManager *manager;
@property (nonatomic, strong) NSMutableArray *runningRequests;
@property (nonatomic, strong) NSMutableArray *pendingRequests;

@end

@implementation LLVideoPlayerDownloader

+ (instancetype)defaultDownloader
{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _manager = [LLVideoPlayerCacheManager defaultManager];
        _maxConcurrentCount = kDefaultConcurrentCount;
        _runningRequests = [NSMutableArray arrayWithCapacity:kDefaultConcurrentCount];
        _pendingRequests = [NSMutableArray array];
    }
    return self;
}

- (void)preloadWithURL:(NSURL *)url
{
    [self preloadWithURL:url bytes:kDefaultBytesLimit];
}

- (void)preloadWithURL:(NSURL *)url bytes:(NSUInteger)bytes
{
    if (nil == url || [url isFileURL]) {
        return;
    }
    if (bytes == 0 || bytes > NSIntegerMax) {
        bytes = NSIntegerMax;
    }
    
    NSRange range = NSMakeRange(0, bytes);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSString *rangeStr = LLRangeToHTTPRangeHeader(range);
    if (rangeStr) {
        [request setValue:rangeStr forHTTPHeaderField:@"Range"];
    }
    
    [self.lock lock];
    [self.pendingRequests addObject:request];
    [self.lock unlock];
    [self processNext];
}

- (void)cancelPreloadWithURL:(NSURL *)url
{
    [self.lock lock];
    for (int i = 0; i < self.pendingRequests.count; i++) {
        NSURLRequest *request = self.pendingRequests[i];
        if ([request.URL isEqual:url]) {
            [self.pendingRequests removeObjectAtIndex:i];
            i--;
        }
    }
    for (LLVideoPlayerDownloadRequest *task in self.runningRequests) {
        if ([task.request.URL isEqual:url]) {
            [task cancel];
        }
    }
    [self.lock unlock];
}

- (void)cancelAllPreloads
{
    [self.lock lock];
    [self.pendingRequests removeAllObjects];
    for (LLVideoPlayerDownloadRequest *task in self.runningRequests) {
        [task cancel];
    }
    [self.lock unlock];
}

#pragma mark - Private

- (BOOL)preloadWithRequest:(NSMutableURLRequest *)request
{
    NSURL *url = request.URL;
    
    // exist?
    for (LLVideoPlayerDownloadRequest *task in self.runningRequests) {
        if ([task.request.URL isEqual:url]) {
            NSString *range1 = [task.request valueForHTTPHeaderField:@"Range"];
            NSString *range2 = [request valueForHTTPHeaderField:@"Range"];
            if ([range1 isEqualToString:range2]) {
                return NO;
            }
        }
    }
    
    // complete?
    LLVideoPlayerCacheFile *cacheFile = [self.manager getCacheFileForURL:url];
    if (cacheFile && [cacheFile isComplete]) {
        return NO;
    }
    
    cacheFile = [self.manager createCacheFileForURL:url];
    LLVideoPlayerDownloadRequest *task = [[LLVideoPlayerDownloadRequest alloc] initWithRequest:request cacheFile:cacheFile];
    __weak typeof(self) wself = self;
    __weak typeof(task) wtask = task;
    [task setCompletedBlock:^(NSError *error) {
        __strong typeof(wself) self = wself;
        __strong typeof(wtask) task = wtask;
        [self.lock lock];
        [self.runningRequests removeObject:task];
        [self.lock unlock];
        [self.manager releaseCacheFileForURL:url];
        [self processNext];
    }];
    [self.runningRequests addObject:task];
    [task resume];
    
    return YES;
}

- (void)processNext
{
    [self.lock lock];
    
    NSInteger count = self.runningRequests.count;
    while (count < self.maxConcurrentCount && self.pendingRequests.count > 0) {
        NSMutableURLRequest *request = [self.pendingRequests firstObject];
        [self.pendingRequests removeObject:request];
        if ([self preloadWithRequest:request]) {
            count++;
        }
    }
    
    [self.lock unlock];
}

@end
