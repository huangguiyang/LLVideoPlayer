//
//  LLVideoPlayerCacheLoader.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheLoader.h"
#import "LLVideoPlayerLoadingRequest.h"
#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerCacheManager.h"

@interface LLVideoPlayerCacheLoader () <LLVideoPlayerLoadingRequestDelegate>

@property (nonatomic, strong) NSURL *streamURL;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSMutableArray *operationQueue;

@end

@implementation LLVideoPlayerCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    for (LLVideoPlayerLoadingRequest *operation in _operationQueue) {
        [operation cancel];
    }
    [[LLVideoPlayerCacheManager defaultManager] releaseCacheFileForURL:_streamURL];
}

- (instancetype)initWithURL:(NSURL *)streamURL
{
    self = [super init];
    if (self) {
        _streamURL = streamURL;
        _operationQueue = [[NSMutableArray alloc] initWithCapacity:4];
        _cacheFile = [[LLVideoPlayerCacheManager defaultManager] createCacheFileForURL:streamURL];
    }
    return self;
}

#pragma mark - LLVideoPlayerLoadingRequestDelegate

- (void)request:(LLVideoPlayerLoadingRequest *)operation didComepleteWithError:(NSError *)error
{
    if (nil == error) {
        [operation.loadingRequest finishLoading];
    } else {
        [operation.loadingRequest finishLoadingWithError:error];
    }
    [self.operationQueue removeObject:operation];
}

#pragma mark - Private

- (void)startLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    LLVideoPlayerLoadingRequest *operation = [[LLVideoPlayerLoadingRequest alloc] initWithLoadingRequest:loadingRequest cacheFile:self.cacheFile];
    operation.delegate = self;
    [self.operationQueue addObject:operation];
    [operation resume];
}

- (void)cancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    for (NSInteger i = 0; i < self.operationQueue.count; i++) {
        LLVideoPlayerLoadingRequest *operation = self.operationQueue[i];
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
