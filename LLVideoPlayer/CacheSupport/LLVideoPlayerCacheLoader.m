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
#import "LLVideoPlayerCacheTask.h"
#import "LLVideoPlayerCachePolicy.h"
#import "LLVideoPlayerInternal.h"

@interface LLVideoPlayerCacheLoader ()

@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSMutableArray<AVAssetResourceLoadingRequest *> *pendingRequests;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *currentRequest;
@property (nonatomic, assign) NSRange currentDataRange;

@end

@implementation LLVideoPlayerCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    [self.operationQueue cancelAllOperations];
}

+ (instancetype)loaderWithCacheFilePath:(NSString *)filePath
{
    return [[self alloc] initWithCacheFilePath:filePath];
}

- (instancetype)initWithCacheFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        self.cacheFile = [LLVideoPlayerCacheFile cacheFileWithFilePath:filePath];
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        self.operationQueue.name = @"com.avplayeritem.llcache";
        self.pendingRequests = [NSMutableArray array];
        self.currentDataRange = LLInvalidRange;
        LLLog(@"[CacheSupport] cache file path: %@", filePath);
    }
    return self;
}

#pragma mark - Private

- (void)cleanupCurrentRequest
{
    [self.pendingRequests removeObject:self.currentRequest];
    self.currentRequest = nil;
    self.currentDataRange = LLInvalidRange;
}

- (void)cancelCurrentRequest:(BOOL)finish
{
    [self.operationQueue cancelAllOperations];
    
    if (finish) {
        if (NO == self.currentRequest.isFinished) {
            [self finishCurrentRequestWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
        }
    } else {
        [self cleanupCurrentRequest];
    }
}

- (void)finishCurrentRequestWithError:(NSError *)error
{
    if (error) {
        [self.currentRequest finishLoadingWithError:error];
    } else {
        [self.currentRequest finishLoading];
    }
    [self cleanupCurrentRequest];
    [self startNextRequest];
}

- (void)startCurrentRequest
{
    
}

- (void)startNextRequest
{
    if (self.currentRequest || self.pendingRequests.count == 0) {
        return;
    }
    
    self.currentRequest = [self.pendingRequests firstObject];
    
    if ([self.currentRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] &&
        self.currentRequest.dataRequest.requestsAllDataToEndOfResource) {
        self.currentDataRange = NSMakeRange(self.currentRequest.dataRequest.requestedOffset, NSIntegerMax);
    } else {
        self.currentDataRange = NSMakeRange(self.currentRequest.dataRequest.requestedOffset, self.currentRequest.dataRequest.requestedLength);
    }
    
    [self startCurrentRequest];
}

- (void)addTaskWithRange:(NSRange)range cached:(BOOL)cached
{
    LLVideoPlayerCacheTask *task = [[LLVideoPlayerCacheTask alloc] initWithCacheFilePath:self.cacheFile loadingRequest:self.currentRequest range:range];
    
    __weak typeof(self) weakSelf = self;
    [task setFinishBlock:^(LLVideoPlayerCacheTask *task, NSError *error) {
        if (task.cancelled || error.code == NSURLErrorCancelled) {
            return;
        }
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (error) {
            [strongSelf finishCurrentRequestWithError:error];
        } else {
            if (strongSelf.operationQueue.operationCount == 1) {
                [strongSelf finishCurrentRequestWithError:nil];
            }
        }
    }];
    
    [self.operationQueue addOperation:task];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self cancelCurrentRequest:YES];
    [self.pendingRequests addObject:loadingRequest];
    [self startNextRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    if (loadingRequest == self.currentRequest) {
        [self cancelCurrentRequest:NO];
    } else {
        [self.pendingRequests removeObject:loadingRequest];
    }
}

@end
