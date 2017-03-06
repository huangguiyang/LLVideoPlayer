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
#import "LLVideoPlayerLocalCacheTask.h"
#import "LLVideoPlayerRemoteCacheTask.h"
#import "LLVideoPlayerCachePolicy.h"
#import "LLVideoPlayerInternal.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"

@interface LLVideoPlayerCacheLoader ()
{
    @private
    NSRange _currentDataRange;
}

@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSMutableArray<AVAssetResourceLoadingRequest *> *pendingRequests;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *currentRequest;
@property (nonatomic, strong) NSHTTPURLResponse *currentResponse;

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
        _currentDataRange = LLInvalidRange;
        LLLog(@"[CacheSupport] cache file path: %@", filePath);
    }
    return self;
}

#pragma mark - Private

- (void)cleanupCurrentRequest
{
    [self.pendingRequests removeObject:self.currentRequest];
    self.currentRequest = nil;
    _currentDataRange = LLInvalidRange;
    self.currentResponse = nil;
}

- (void)cancelCurrentRequest:(BOOL)finish
{
    [self.operationQueue cancelAllOperations];
    
    if (finish) {
        if (self.currentRequest && NO == self.currentRequest.isFinished) {
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

- (void)startNextRequest
{
    if (self.currentRequest || self.pendingRequests.count == 0) {
        return;
    }
    
    self.currentRequest = [self.pendingRequests firstObject];
    
    if ([self.currentRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] &&
        self.currentRequest.dataRequest.requestsAllDataToEndOfResource) {
        _currentDataRange = NSMakeRange(self.currentRequest.dataRequest.requestedOffset, NSUIntegerMax);
    } else {
        _currentDataRange = NSMakeRange(self.currentRequest.dataRequest.requestedOffset, self.currentRequest.dataRequest.requestedLength);
    }
    
    if (nil == self.currentResponse && self.cacheFile.responseHeaders.count > 0) {
        if (_currentDataRange.length == NSUIntegerMax) {
            _currentDataRange.length = [self.cacheFile fileLength] - _currentDataRange.location;
        }
        
        NSMutableDictionary *responseHeaders = [_cacheFile.responseHeaders mutableCopy];
        NSString *contentRangeKey = @"Content-Range";
        BOOL supportRange = responseHeaders[contentRangeKey] != nil;
        
        if (supportRange && LLValidByteRange(_currentDataRange)) {
            responseHeaders[contentRangeKey] = LLRangeToHTTPRangeResponseHeader(_currentDataRange, [self.cacheFile fileLength]);
        } else {
            [responseHeaders removeObjectForKey:contentRangeKey];
        }
        
        responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu",_currentDataRange.length];
        NSInteger statusCode = supportRange ? 206 : 200;
        self.currentResponse = [[NSHTTPURLResponse alloc] initWithURL:self.currentRequest.request.URL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:responseHeaders];
        [self.currentRequest ll_fillContentInformation:self.currentResponse];
    }
    
    [self startCurrentRequest];
}

- (void)startCurrentRequest
{
    self.operationQueue.suspended = YES;
    
    if (_currentDataRange.length == NSUIntegerMax) {
        [self addTaskWithRange:NSMakeRange(_currentDataRange.location, NSUIntegerMax) cached:NO];
    } else {
        NSUInteger start = _currentDataRange.location;
        NSUInteger end = NSMaxRange(_currentDataRange);
        
        while (start < end) {
            NSRange firstNotCachedRange = [self.cacheFile firstNotCachedRangeFromPosition:start];
            if (NO == LLValidFileRange(firstNotCachedRange)) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:[self.cacheFile maxCachedLength] > 0];
                start = end;
            } else if (firstNotCachedRange.location >= end) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:YES];
                start = end;
            } else if (firstNotCachedRange.location >= start) {
                if (firstNotCachedRange.location > start) {
                    [self addTaskWithRange:NSMakeRange(start, firstNotCachedRange.location) cached:YES];
                }
                
                NSUInteger notCachedEnd = MIN(NSMaxRange(firstNotCachedRange), end);
                [self addTaskWithRange:NSMakeRange(firstNotCachedRange.location, notCachedEnd - firstNotCachedRange.location) cached:NO];
                start = notCachedEnd;
            } else {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:YES];
                start = end;
            }
        }
    }
    
    self.operationQueue.suspended = NO;
}

- (void)addTaskWithRange:(NSRange)range cached:(BOOL)cached
{
    LLVideoPlayerCacheTask *task;
    
    if (cached) {
       task = [[LLVideoPlayerLocalCacheTask alloc] initWithCacheFilePath:self.cacheFile loadingRequest:self.currentRequest range:range];
    } else {
        task = [[LLVideoPlayerRemoteCacheTask alloc] initWithCacheFilePath:self.cacheFile loadingRequest:self.currentRequest range:range];
        [(LLVideoPlayerRemoteCacheTask *)task setResponse:self.currentResponse];
    }
    
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
