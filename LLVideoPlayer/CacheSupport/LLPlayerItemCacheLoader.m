//
//  LLPlayerItemCacheLoader.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLPlayerItemCacheLoader.h"
#import "LLPlayerItemCacheFile.h"
#import "LLPlayerItemCacheUtils.h"
#import "LLPlayerItemCacheTask.h"
#import "LLPlayerItemCachePolicy.h"

@interface LLPlayerItemCacheLoader ()

@property (nonatomic, strong) LLPlayerItemCacheFile *cacheFile;
@property (nonatomic, strong) NSOperationQueue *cacheQueue;
@property (nonatomic, strong) NSMutableArray<AVAssetResourceLoadingRequest *> *pendingRequests;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *currentRequest;
@property (nonatomic, assign) NSRange currentDataRange;

@end

@implementation LLPlayerItemCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    [self.cacheQueue cancelAllOperations];
}

+ (instancetype)cacheLoaderWithCacheFilePath:(NSString *)filePath
{
    return [[self alloc] initWithCacheFilePath:filePath];
}

- (instancetype)initWithCacheFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        self.cacheFile = [LLPlayerItemCacheFile cacheFileWithFilePath:filePath];
        self.cacheQueue = [[NSOperationQueue alloc] init];
        self.cacheQueue.maxConcurrentOperationCount = 1;
        self.cacheQueue.name = @"com.avplayeritem.llcache";
        self.pendingRequests = [NSMutableArray array];
        self.currentDataRange = LLInvalidRange;
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

- (void)cancelCurrentRequest
{
    
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
    LLPlayerItemCacheTask *task = [[LLPlayerItemCacheTask alloc] initWithCacheFilePath:self.cacheFile loadingRequest:self.currentRequest range:range];
    
    __weak typeof(self) weakSelf = self;
    [task setFinishBlock:^(LLPlayerItemCacheTask *task, NSError *error) {
        if (task.cancelled || error.code == NSURLErrorCancelled) {
            return;
        }
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (error) {
            [strongSelf finishCurrentRequestWithError:error];
        } else {
            if (strongSelf.cacheQueue.operationCount == 1) {
                [strongSelf finishCurrentRequestWithError:nil];
            }
        }
    }];
    
    [self.cacheQueue addOperation:task];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self cancelCurrentRequest];
    [self.pendingRequests addObject:loadingRequest];
    [self startNextRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    if (loadingRequest == self.currentRequest) {
        [self cancelCurrentRequest];
    } else {
        [self.pendingRequests removeObject:loadingRequest];
    }
}

@end
