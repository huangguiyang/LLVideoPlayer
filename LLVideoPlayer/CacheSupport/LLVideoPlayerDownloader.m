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
#define kDefaultConcurrentCount 2

typedef NS_ENUM(NSInteger, LLVideoPlayerDownloaderState) {
    LLVideoPlayerDownloaderStateIdle,
    LLVideoPlayerDownloaderStatePaused
};

static char kQueueSpecificKey[1];

@interface LLVideoPlayerDownloader () {
    dispatch_queue_t _queue;
}

@property (nonatomic, weak) LLVideoPlayerCacheManager *manager;
@property (nonatomic, strong) NSMutableArray<LLVideoPlayerDownloadRequest *> *runningTasks;
@property (nonatomic, strong) NSMutableArray<NSURLRequest *> *pendingRequests;
@property (nonatomic, assign) LLVideoPlayerDownloaderState state;

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

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("LLVideoPlayerDownloader", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue, kQueueSpecificKey, (__bridge void *)_queue, NULL);
        _manager = [LLVideoPlayerCacheManager defaultManager];
        _maxConcurrentCount = kDefaultConcurrentCount;
        _runningTasks = [NSMutableArray array];
        _pendingRequests = [NSMutableArray array];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cacheLoaderBusy)
                                                     name:@"LLVideoPlayerCacheLoaderBusy"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cacheLoaderIdle)
                                                     name:@"LLVideoPlayerCacheLoaderIdle"
                                                   object:nil];
    }
    return self;
}

- (void)scheduleWithBlock:(dispatch_block_t)block {
    if (dispatch_get_specific(kQueueSpecificKey) == dispatch_queue_get_specific(_queue, kQueueSpecificKey)) {
        @autoreleasepool {
            if (block) block();
        }
    } else {
        dispatch_async(_queue, ^{
            @autoreleasepool {
                if (block) block();
            }
        });
    }
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
    
    [self scheduleWithBlock:^{
        [self.pendingRequests addObject:request];
        [self processNextNoLock];
    }];
}

- (void)cancelPreloadWithURL:(NSURL *)url
{
    if (nil == url || [url isFileURL]) {
        return;
    }
    
    [self scheduleWithBlock:^{
        for (int i = 0; i < self.pendingRequests.count; i++) {
            NSURLRequest *request = self.pendingRequests[i];
            if ([request.URL isEqual:url]) {
                [self.pendingRequests removeObjectAtIndex:i];
                i--;
            }
        }
        for (LLVideoPlayerDownloadRequest *task in self.runningTasks) {
            if ([task.request.URL isEqual:url]) {
                [task cancel];
            }
        }
    }];
}

- (void)cancelAllPreloads
{
    [self scheduleWithBlock:^{
        [self.pendingRequests removeAllObjects];
        for (LLVideoPlayerDownloadRequest *task in self.runningTasks) {
            [task cancel];
        }
    }];
}

#pragma mark - Private

- (BOOL)preloadWithRequest:(NSURLRequest *)request
{
    NSURL *url = request.URL;
    
    // exist?
    for (LLVideoPlayerDownloadRequest *task in self.runningTasks) {
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
        [self scheduleWithBlock:^{
            [self.runningTasks removeObject:task];
            [self.manager releaseCacheFileForURL:url];
            [self processNextNoLock];
        }];
    }];
    [self.runningTasks addObject:task];
    [task resume];
    
    return YES;
}

- (void)processNextNoLock
{
    if (self.state == LLVideoPlayerDownloaderStateIdle) {
        NSInteger count = self.runningTasks.count;
        while (count < self.maxConcurrentCount && self.pendingRequests.count > 0) {
            NSURLRequest *request = [self.pendingRequests firstObject];
            [self.pendingRequests removeObject:request];
            if ([self preloadWithRequest:request]) {
                count++;
            }
        }
    }
}

- (void)setState:(LLVideoPlayerDownloaderState)state
{
    if (_state == state) {
        return;
    }
    
    [self scheduleWithBlock:^{
        _state = state;
        if (state == LLVideoPlayerDownloaderStateIdle) {
            [self processNextNoLock];
        } else if (state == LLVideoPlayerDownloaderStatePaused) {
            for (LLVideoPlayerDownloadRequest *task in self.runningTasks) {
                [self.pendingRequests addObject:task.request];
                [task cancel];
            }
        }
    }];
}

#pragma mark - Cache Loader Notification

- (void)cacheLoaderBusy
{
    self.state = LLVideoPlayerDownloaderStatePaused;
}

- (void)cacheLoaderIdle
{
    self.state = LLVideoPlayerDownloaderStateIdle;
}

@end
