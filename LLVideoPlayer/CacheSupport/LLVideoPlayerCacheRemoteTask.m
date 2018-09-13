//
//  LLVideoPlayerCacheRemoteTask.m
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerCacheRemoteTask.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSURLResponse+LLVideoPlayer.h"

#define MAX_MEM_SIZE (1024 * 1024)

@interface LLVideoPlayerCacheRemoteTask () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    NSURLConnection *_connection;
    NSInteger _offset;
    NSMutableData *_mutableData;
    NSRecursiveLock *_lock;
}

@end

@implementation LLVideoPlayerCacheRemoteTask

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super initWithRequest:loadingRequest range:range cacheFile:cacheFile];
    if (self) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_connection cancel];
}

- (void)resume
{
    [super resume];
    
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wself) self = wself;
        
        [_lock lock];
        if ([self isCancelled]) {
            return;
        }
        
        NSMutableURLRequest *request = [self.loadingRequest.request mutableCopy];
        request.URL = [self.loadingRequest.request.URL ll_originalSchemeURL];
        request.cachePolicy = NSURLRequestReloadIgnoringCacheData;  // very important
        _offset = 0;
        _mutableData = [NSMutableData data];
        
        NSString *rangeString = LLRangeToHTTPRangeHeader(self.range);
        if (rangeString) {
            [request setValue:rangeString forHTTPHeaderField:@"Range"];
            _offset = self.range.location;
        }
        
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_connection start];
        [_lock unlock];
    });
}

- (void)cancel
{
    [_lock lock];
    [_connection cancel];
    _connection = nil;
    [self synchronize];
    [super cancel];
    [_lock unlock];
}

- (void)synchronize
{
    if ([_mutableData length] > 0) {
        [self.cacheFile writeData:_mutableData atOffset:_offset];
        _mutableData = nil;
        [self.cacheFile synchronize];
    }
}

#pragma mark - NSURLConnectionDelegate && NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [_lock lock];
    [self synchronize];
    [_lock unlock];
    if ([self.delegate respondsToSelector:@selector(task:didFailWithError:)]) {
        [self.delegate task:self didFailWithError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [_lock lock];
    [self synchronize];
    [_lock unlock];
    if ([self.delegate respondsToSelector:@selector(taskDidFinish:)]) {
        [self.delegate taskDidFinish:self];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.cacheFile receivedResponse:response forLoadingRequest:self.loadingRequest];
    
    if (NO == [response ll_supportRange]) {
        _offset = 0;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.loadingRequest.dataRequest respondWithData:data];
    
    // save local
    [_lock lock];
    [_mutableData appendData:data];
    if (_mutableData.length >= MAX_MEM_SIZE) {
        [self.cacheFile writeData:_mutableData atOffset:_offset];
        _offset += [_mutableData length];
        _mutableData = [NSMutableData data];
    }
    [_lock unlock];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response) {
        self.loadingRequest.redirect = request;
    }
    
    return request;
}

@end
