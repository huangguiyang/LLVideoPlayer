//
//  LLVideoPlayerCacheLoader.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheLoader.h"
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

+ (instancetype)loaderWithCacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    return [[self alloc] initWithCacheFile:cacheFile];
}

- (instancetype)initWithCacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        _cacheFile = cacheFile;
        _operationQueue = [[NSMutableArray alloc] initWithCapacity:4];
    }
    return self;
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
