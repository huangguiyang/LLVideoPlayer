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
#import "NSURLResponse+LLVideoPlayer.h"

static NSString * const kLLVideoPlayerCacheLoaderBusy = @"LLVideoPlayerCacheLoaderBusy";
static NSString * const kLLVideoPlayerCacheLoaderIdle = @"LLVideoPlayerCacheLoaderIdle";

@interface LLVideoPlayerCacheLoader () <LLVideoPlayerLoadingRequestDelegate>

@property (nonatomic, strong) NSURL *streamURL;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSMutableArray *operationQueue;
@property (nonatomic, assign) long long totalLength;
@property (nonatomic, assign) long long loadedLength;
@property (nonatomic, assign) BOOL notifyStart;
@property (nonatomic, assign) BOOL notifyEnough;

@end

@implementation LLVideoPlayerCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    for (LLVideoPlayerLoadingRequest *operation in _operationQueue) {
        [operation cancel];
    }
    [[LLVideoPlayerCacheManager defaultManager] releaseCacheFileForURL:_streamURL];
    if (NO == _notifyEnough) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kLLVideoPlayerCacheLoaderIdle object:nil];
    }
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
        /*
         NOTE: The loading ranges may be overlapped,
               so `loadedLength` may be greater than `totalLength`.
         */
        self.loadedLength += operation.loadingRequest.dataRequest.requestedLength;
        if (self.totalLength == 0) {
            self.totalLength = [operation.loadingRequest.response ll_totalLength];
        }
    } else {
        [operation.loadingRequest finishLoadingWithError:error];
    }
    [self.operationQueue removeObject:operation];
    
    if (NO == self.notifyEnough && self.totalLength > 0 && self.loadedLength * 4 >= self.totalLength * 3) {
        self.notifyEnough = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:kLLVideoPlayerCacheLoaderIdle object:nil];
    }
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
    if (NO == self.notifyStart) {
        self.notifyStart = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:kLLVideoPlayerCacheLoaderBusy object:nil];
    }
    [self startLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self cancelLoadingRequest:loadingRequest];
}

@end
