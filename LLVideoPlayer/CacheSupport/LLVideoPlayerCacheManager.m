//
//  LLVideoPlayerCacheManager.m
//  LLVideoPlayer
//
//  Created by mario on 2018/10/26.
//

#import "LLVideoPlayerCacheManager.h"
#import <objc/runtime.h>

#define kMinFreeSpaceLimit (1ULL << 30)

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug 1140.11
#else
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug NSFoundationVersionNumber_iOS_8_0
#endif

static uint64_t disk_free_capacity(void)
{
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) {
        return -1;
    }
    int64_t space = [attrs[NSFileSystemFreeSize] longLongValue];
    if (space < 0) {
        space = -1;
    }
    return space;
}

static dispatch_queue_t url_session_creation_queue()
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("LLVideoPlayer.session.creation", DISPATCH_QUEUE_SERIAL);
    });
    
    return queue;
}

static void create_url_session_task_safely(dispatch_block_t block)
{
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_With_Fixed_5871104061079552_bug) {
        dispatch_sync(url_session_creation_queue(), block);
    } else {
        block();
    }
}

static char LLVideoPlayerCacheFileRefCountKey;

@implementation LLVideoPlayerCacheFile (LLVideoPlayerCacheManager)

- (NSInteger)_priv_refcount
{
    NSNumber *num = objc_getAssociatedObject(self, &LLVideoPlayerCacheFileRefCountKey);
    return [num integerValue];
}

- (void)set_priv_refcount:(NSInteger)_priv_refcount
{
    NSNumber *num = [NSNumber numberWithInteger:_priv_refcount];
    objc_setAssociatedObject(self, &LLVideoPlayerCacheFileRefCountKey, num, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)_inc_priv_refcount:(NSInteger)inc
{
    NSInteger num = [self _priv_refcount] + inc;
    [self set_priv_refcount:num];
    return num;
}

@end

@interface LLVideoPlayerCacheManager () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) NSMutableDictionary *fileMap;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *delegateMap;

@end

@implementation LLVideoPlayerCacheManager

+ (instancetype)defaultManager {
    static id manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (void)dealloc
{
    [_session invalidateAndCancel];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _fileMap = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
        _delegateMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (LLVideoPlayerCacheFile *)createCacheFileForURL:(NSURL *)url {
    if (nil == url) {
        return nil;
    }
    [self.lock lock];
    LLVideoPlayerCacheFile *cacheFile = [self.fileMap objectForKey:url];
    if (nil == cacheFile) {
        cacheFile = [[LLVideoPlayerCacheFile alloc] initWithURL:url];
        [self.fileMap setObject:cacheFile forKey:url];
    }
    [cacheFile _inc_priv_refcount:1];
    [self.lock unlock];
    return cacheFile;
}

- (LLVideoPlayerCacheFile *)getCacheFileForURL:(NSURL *)url {
    if (nil == url) {
        return nil;
    }
    [self.lock lock];
    LLVideoPlayerCacheFile *cacheFile = [self.fileMap objectForKey:url];
    [self.lock unlock];
    return cacheFile;
}

- (void)releaseCacheFileForURL:(NSURL *)url {
    if (nil == url) {
        return;
    }
    [self.lock lock];
    LLVideoPlayerCacheFile *cacheFile = [self.fileMap objectForKey:url];
    if (cacheFile) {
        NSInteger refCount = [cacheFile _inc_priv_refcount:-1];
        if (refCount == 0) {
            [self.fileMap removeObjectForKey:url];
        } else if (refCount < 0) {
            // WARNING: should never go here
            [self.fileMap removeObjectForKey:url];
        }
    }
    [self.lock unlock];
}

- (id<NSURLSessionDataDelegate>)delegateForTask:(NSURLSessionTask *)task
{
    NSParameterAssert(task);
    
    id<NSURLSessionDataDelegate> delegate = nil;
    [self.lock lock];
    delegate = self.delegateMap[@(task.taskIdentifier)];
    [self.lock unlock];
    
    return delegate;
}

- (void)removeDelegateForTask:(NSURLSessionTask *)task
{
    NSParameterAssert(task);
    
    [self.lock lock];
    [self.delegateMap removeObjectForKey:@(task.taskIdentifier)];
    [self.lock unlock];
}

- (void)setDelegate:(id<NSURLSessionDataDelegate>)delegate forTask:(NSURLSessionTask *)task
{
    NSParameterAssert(delegate);
    NSParameterAssert(task);
    
    [self.lock lock];
    self.delegateMap[@(task.taskIdentifier)] = delegate;
    [self.lock unlock];
}

- (NSURLSessionDataTask *)createDataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate
{
    __block NSURLSessionDataTask *dataTask = nil;
    create_url_session_task_safely(^{
        dataTask = [self.session dataTaskWithRequest:request];
    });
    
    [self setDelegate:delegate forTask:dataTask];
    
    return dataTask;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    id<NSURLSessionDataDelegate> delegate = [self delegateForTask:task];
    
    if (delegate) {
        [delegate URLSession:session task:task didCompleteWithError:error];
        
        [self removeDelegateForTask:task];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    id<NSURLSessionDataDelegate> delegate = [self delegateForTask:dataTask];
    [delegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    id<NSURLSessionDataDelegate> delegate = [self delegateForTask:dataTask];
    [delegate URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    id<NSURLSessionDataDelegate> delegate = [self delegateForTask:task];
    [delegate URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
}

#pragma mark - Clean

+ (void)enumerateDirectory:(NSString *)directory usingBlock:(void (^)(NSString *path, NSDictionary *attr))block
{
    NSParameterAssert(block);
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:&error];
    if (error) {
        return;
    }
    
    for (NSString *name in contents) {
        if ([name pathExtension].length > 0) {
            continue;
        }
        
        NSString *path = [directory stringByAppendingPathComponent:name];
        error = nil;
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        if (error) {
            continue;
        }
        if (NO == [[attr fileType] isEqualToString:NSFileTypeRegular]) {
            continue;
        }
        
        block(path, attr);
    }
}

- (void)clearAllCache
{
    NSString *dir = [LLVideoPlayerCacheFile cacheDirectory];
    [self.lock lock];
    [LLVideoPlayerCacheManager enumerateDirectory:dir usingBlock:^(NSString *path, NSDictionary *attr) {
        [self removeCacheAtPathNoLock:path];
    }];
    [self.lock unlock];
}

- (void)removeCacheForURL:(NSURL *)url
{
    [self removeCacheAtPath:[LLVideoPlayerCacheFile cacheFilePathWithURL:url]];
}

- (void)removeCacheAtPathNoLock:(NSString *)path
{
    BOOL found = NO;
    for (LLVideoPlayerCacheFile *cacheFile in self.fileMap.allValues) {
        if ([cacheFile.cacheFilePath isEqualToString:path]) {
            found = YES;
            break;
        }
    }
    if (NO == found) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        [fileManager removeItemAtPath:path error:nil];
        
        NSString *index = [NSString stringWithFormat:@"%@.%@", path, kLLVideoCacheFileExtensionIndex];
        [fileManager removeItemAtPath:index error:nil];
    }
}

- (void)removeCacheAtPath:(NSString *)path
{
    [self.lock lock];
    [self removeCacheAtPathNoLock:path];
    [self.lock unlock];
}

- (void)cleanCacheWithPolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    NSString *directory = [LLVideoPlayerCacheFile cacheDirectory];
    if (nil == cachePolicy) {
        cachePolicy = [LLVideoPlayerCachePolicy defaultPolicy];
    }
    
    __block NSUInteger totalSize = 0;
    NSDate *now = [NSDate date];
    NSMutableArray *paths = [NSMutableArray array];
    
    [LLVideoPlayerCacheManager enumerateDirectory:directory usingBlock:^(NSString *path, NSDictionary *attr) {
        NSDate *date = [attr fileCreationDate];
        NSInteger hours = [now timeIntervalSinceDate:date] / 3600;
        if (hours >= cachePolicy.outdatedHours) {
            [self removeCacheAtPath:path];
            return;
        }
        
        [paths addObject:path];
        totalSize += [attr fileSize];
    }];
    
    const uint64_t minFreeSpaceLimit = kMinFreeSpaceLimit;
    int64_t diskSpaceFreeSize = disk_free_capacity();
    
    for (NSString *path in paths) {
        if (totalSize < cachePolicy.diskCapacity && diskSpaceFreeSize >= minFreeSpaceLimit) {
            break;
        }
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        [self removeCacheAtPath:path];
        totalSize -= [attr fileSize];
        diskSpaceFreeSize += [attr fileSize];
    }
}

@end
