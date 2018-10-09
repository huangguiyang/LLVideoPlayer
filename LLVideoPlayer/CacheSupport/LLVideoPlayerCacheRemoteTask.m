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

@interface LLVideoPlayerCacheRemoteTask () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    NSURLConnection *_connection;
    NSInteger _offset;
}

@end

@implementation LLVideoPlayerCacheRemoteTask

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
        
        if ([self isCancelled]) {
            return;
        }
        
        NSMutableURLRequest *request = [self.loadingRequest.request mutableCopy];
        request.URL = [self.loadingRequest.request.URL ll_originalSchemeURL];
        request.cachePolicy = NSURLRequestReloadIgnoringCacheData;  // very important
        _offset = 0;
        
        NSString *rangeString = LLRangeToHTTPRangeHeader(self.range);
        if (rangeString) {
            [request setValue:rangeString forHTTPHeaderField:@"Range"];
            _offset = self.range.location;
        }
        
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_connection start];
    });
}

- (void)cancel
{
    [_connection cancel];
    _connection = nil;
    [self.cacheFile synchronize];
    [super cancel];
}

#pragma mark - NSURLConnectionDelegate && NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.cacheFile synchronize];
    if ([self.delegate respondsToSelector:@selector(task:didFailWithError:)]) {
        [self.delegate task:self didFailWithError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.cacheFile synchronize];
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
    [self.cacheFile writeData:data atOffset:_offset];
    _offset += [data length];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response) {
        self.loadingRequest.redirect = request;
    }
    
    return request;
}

@end
