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
#import "NSString+LLVideoPlayer.h"
#import "LLVideoPlayerCacheOperation.h"

@interface LLVideoPlayerCacheLoader () <LLVideoPlayerCacheOperationDelegate>

@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSMutableArray *operationQueue;

@end

@implementation LLVideoPlayerCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    for (LLVideoPlayerCacheOperation *operation in self.operationQueue) {
        [operation cancel];
    }
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
        self.cacheFile = [LLVideoPlayerCacheFile cacheFileWithFilePath:path cachePolicy:cachePolicy];
        self.operationQueue = [[NSMutableArray alloc] initWithCapacity:4];
    }
    return self;
}

- (BOOL)isCacheComplete
{
    return [self.cacheFile isComplete];
}

#pragma mark - LLVideoPlayerCacheOperationDelegate

- (void)operationDidFinish:(LLVideoPlayerCacheOperation *)operation
{
    [operation.loadingRequest finishLoading];
    [self.operationQueue removeObject:operation];
}

- (void)operation:(LLVideoPlayerCacheOperation *)operation didFailWithError:(NSError *)error
{
    [operation.loadingRequest finishLoadingWithError:error];
    [self.operationQueue removeObject:operation];
}

#pragma mark - Private

- (void)startLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    LLVideoPlayerCacheOperation *operation = [LLVideoPlayerCacheOperation operationWithLoadingRequest:loadingRequest cacheFile:self.cacheFile];
    operation.delegate = self;
    [self.operationQueue addObject:operation];
    [operation resume];
}

- (void)cancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    for (NSInteger i = 0; i < self.operationQueue.count; i++) {
        LLVideoPlayerCacheOperation *operation = self.operationQueue[i];
        if (operation.loadingRequest == loadingRequest) {
            [operation cancel];
            [self.operationQueue removeObjectAtIndex:i];
            i--;
        }
    }
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self startLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self cancelLoadingRequest:loadingRequest];
}

@end
