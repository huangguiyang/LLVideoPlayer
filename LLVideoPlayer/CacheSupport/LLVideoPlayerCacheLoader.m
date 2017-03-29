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
#import "NSString+LLVideoPlayer.h"

@interface LLVideoPlayerCacheLoader ()
{
    @private
    NSRange _currentDataRange;
    LLVideoPlayerCacheFile *_cacheFile;
    NSOperationQueue *_operationQueue;
    NSMutableArray<AVAssetResourceLoadingRequest *> *_pendingRequests;
    AVAssetResourceLoadingRequest *_currentRequest;
    NSHTTPURLResponse *_currentResponse;
}

@end

@implementation LLVideoPlayerCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    [self cleanupOperationQueue];
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
        [self createOperationQueue];
        _pendingRequests = [NSMutableArray array];
        _currentDataRange = LLInvalidRange;
        LLLog(@"[CacheSupport] cache file path: %@", path);
    }
    return self;
}

#pragma mark - Private

- (void)createOperationQueue
{
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.maxConcurrentOperationCount = 1;
    _operationQueue.name = @"com.avplayeritem.llcache";
    [_operationQueue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)cleanupOperationQueue
{
    [_operationQueue removeObserver:self forKeyPath:@"operationCount"];
    [_operationQueue cancelAllOperations];
    _operationQueue = nil;
}

- (void)cleanupCurrentRequest
{
    [_pendingRequests removeObject:_currentRequest];
    _currentRequest = nil;
    _currentDataRange = LLInvalidRange;
    _currentResponse = nil;
}

- (void)cancelCurrentRequest
{
    [self cleanupOperationQueue];
    [self cleanupCurrentRequest];
}

- (void)finishCurrentRequestWithError:(NSError *)error
{
    if (error) {
        [_currentRequest finishLoadingWithError:error];
    } else {
        [_currentRequest finishLoading];
    }
    [self cleanupCurrentRequest];
    [self startNextRequest];
}

- (void)startNextRequest
{
    if (_currentRequest || _pendingRequests.count == 0) {
        return;
    }
    
    _currentRequest = [_pendingRequests firstObject];
    
    if ([_currentRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] &&
        _currentRequest.dataRequest.requestsAllDataToEndOfResource) {
        _currentDataRange = NSMakeRange(_currentRequest.dataRequest.requestedOffset, NSIntegerMax);
    } else {
        _currentDataRange = NSMakeRange(_currentRequest.dataRequest.requestedOffset, _currentRequest.dataRequest.requestedLength);
    }
    
    if (nil == _currentResponse && _cacheFile.responseHeaders.count > 0) {
        if (_currentDataRange.length == NSIntegerMax) {
            _currentDataRange.length = [_cacheFile fileLength] - _currentDataRange.location;
        }
        
        NSMutableDictionary *responseHeaders = [_cacheFile.responseHeaders mutableCopy];
        NSString *contentRangeKey = @"Content-Range";
        BOOL supportRange = responseHeaders[contentRangeKey] != nil;
        
        if (supportRange && LLValidByteRange(_currentDataRange)) {
            responseHeaders[contentRangeKey] = LLRangeToHTTPRangeResponseHeader(_currentDataRange, [_cacheFile fileLength]);
        } else {
            [responseHeaders removeObjectForKey:contentRangeKey];
        }
        
        responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu", _currentDataRange.length];
        NSInteger statusCode = supportRange ? 206 : 200;
        _currentResponse = [[NSHTTPURLResponse alloc] initWithURL:_currentRequest.request.URL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:responseHeaders];
        [_currentRequest ll_fillContentInformation:_currentResponse];
    }
    
    [self startCurrentRequest];
}

- (void)startCurrentRequest
{
    [self createOperationQueue];
    
    _operationQueue.suspended = YES;
    
    if (_currentDataRange.length == NSIntegerMax) {
        NSUInteger start = _currentDataRange.location;
        
        NSRange firstNotCachedRange = [_cacheFile firstNotCachedRangeFromPosition:start];
        if (NO == LLValidFileRange(firstNotCachedRange)) {
            [self addTaskWithRange:NSMakeRange(start, NSIntegerMax) cached:NO];
        } else {
            [self addTaskWithRange:NSMakeRange(start, firstNotCachedRange.location - start) cached:YES];
            [self addTaskWithRange:NSMakeRange(firstNotCachedRange.location, NSIntegerMax) cached:NO];
        }
    } else {
        NSUInteger start = _currentDataRange.location;
        NSUInteger end = NSMaxRange(_currentDataRange);
        
        while (start < end) {
            NSRange firstNotCachedRange = [_cacheFile firstNotCachedRangeFromPosition:start];
            if (NO == LLValidFileRange(firstNotCachedRange)) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:[_cacheFile maxCachedLength] > 0];
                start = end;
            } else if (firstNotCachedRange.location >= end) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:YES];
                start = end;
            } else if (firstNotCachedRange.location >= start) {
                if (firstNotCachedRange.location > start) {
                    [self addTaskWithRange:NSMakeRange(start, firstNotCachedRange.location - start) cached:YES];
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
    
    _operationQueue.suspended = NO;
}

- (void)addTaskWithRange:(NSRange)range cached:(BOOL)cached
{
    LLVideoPlayerCacheTask *task;
    
    if (cached) {
       task = [[LLVideoPlayerLocalCacheTask alloc] initWithCacheFilePath:_cacheFile loadingRequest:_currentRequest range:range];
    } else {
        task = [[LLVideoPlayerRemoteCacheTask alloc] initWithCacheFilePath:_cacheFile loadingRequest:_currentRequest range:range];
        [(LLVideoPlayerRemoteCacheTask *)task setResponse:_currentResponse];
    }
    
    [task addObserver:self forKeyPath:@"finished" options:NSKeyValueObservingOptionNew context:nil];
    
    [_operationQueue addOperation:task];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([object isKindOfClass:[LLVideoPlayerCacheTask class]]) {
        
        if ([keyPath isEqualToString:@"finished"]) {
            BOOL finished = [change[NSKeyValueChangeNewKey] boolValue];
            if (finished) {                
                __weak typeof(self) weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    
                    LLVideoPlayerCacheTask *task = (LLVideoPlayerCacheTask *)object;
                    [task removeObserver:strongSelf forKeyPath:@"finished"];
                    
                    if (task.cancelled || task.error.code == NSURLErrorCancelled) {
                        return;
                    }
                    
                    if (task.error) {
                        [strongSelf finishCurrentRequestWithError:task.error];
                    }
                });
            }
        }
    } else if ([object isKindOfClass:[NSOperationQueue class]]) {
        
        if ([keyPath isEqualToString:@"operationCount"]) {
            NSOperationQueue *queue = (NSOperationQueue *)object;
            NSUInteger operationCount = [change[NSKeyValueChangeNewKey] integerValue];
            if (operationCount == 0) {
                // finished
                __weak typeof(self) weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    
                    [strongSelf finishCurrentRequestWithError:nil];
                });
            }
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [_pendingRequests addObject:loadingRequest];
    [self startNextRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    if (loadingRequest == _currentRequest) {
        [self cancelCurrentRequest];
    } else {
        [_pendingRequests removeObject:loadingRequest];
    }
}

@end
