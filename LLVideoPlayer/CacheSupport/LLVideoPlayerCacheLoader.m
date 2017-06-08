//
//  LLVideoPlayerCacheLoader.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheLoader.h"
#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerCacheUtils.h"
#import "LLVideoPlayerCachePolicy.h"
#import "LLVideoPlayerInternal.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "NSString+LLVideoPlayer.h"
#import "LLVideoPlayerCacheOperation.h"
#include <sys/sysctl.h>

static unsigned int numberOfCores(void)
{
    size_t len;
    unsigned int ncpu;
    
    len = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
    
    return ncpu;
}

@interface LLVideoPlayerCacheLoader ()
{
    @private
    LLVideoPlayerCacheFile *_cacheFile;
    NSOperationQueue *_operationQueue;
    NSHTTPURLResponse *_currentResponse;
}

@end

@implementation LLVideoPlayerCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    [_operationQueue removeObserver:self forKeyPath:@"operationCount"];
    [_operationQueue cancelAllOperations];
}

+ (instancetype)loaderWithURL:(NSURL *)url cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    return [[self alloc] initWithURL:url cachePolicy:cachePolicy];
}

- (instancetype)initWithURL:(NSURL *)url cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    self = [super init];
    if (self) {
        NSString *name = [url.absoluteString ll_md5];
        NSString *path = [[LLVideoPlayerCacheFile cacheDirectory] stringByAppendingPathComponent:name];
        _cacheFile = [LLVideoPlayerCacheFile cacheFileWithFilePath:path cachePolicy:cachePolicy];
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.name = @"com.llvideoplayer.cache";
        _operationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        _operationQueue.maxConcurrentOperationCount = numberOfCores();
        [_operationQueue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:nil];
        TLog(@"[CacheSupport] cache file path: %@", path);
    }
    return self;
}

#pragma mark - Private

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"operationCount"]) {
        NSInteger count = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        TLog(@"observeValueForKeyPath: %@ == %ld", keyPath, count);
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)startLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    LLVideoPlayerCacheOperation *operation = [LLVideoPlayerCacheOperation operationWithLoadingRequest:loadingRequest cacheFile:_cacheFile];
    [_operationQueue addOperation:operation];
}

- (void)cancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSArray<LLVideoPlayerCacheOperation *> *operations = _operationQueue.operations;
    for (LLVideoPlayerCacheOperation *operation in operations) {
        if (operation.loadingRequest == loadingRequest) {
            [operation cancel];
            break;
        }
    }
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    TLog(@"[Comming] %@", loadingRequest);
    [self startLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    TLog(@"[Cancel] %@", loadingRequest);
    [self cancelLoadingRequest:loadingRequest];
}

@end
