//
//  LLVideoPlayerCacheRemoteTask.m
//  Pods
//
//  Created by mario on 2017/6/23.
//
//

#import "LLVideoPlayerCacheRemoteTask.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "LLVideoPlayerInternal.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"

#define MAX_MEM_SIZE (1024 * 1024)

@interface LLVideoPlayerCacheRemoteTask () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    NSURLConnection *_connection;
    NSInteger _offset;
    NSMutableData *_mutableData;
    CFRunLoopRef _runLoop;
}

@end

@implementation LLVideoPlayerCacheRemoteTask

- (void)dealloc
{
    [_connection cancel];
}

- (void)main
{
    @autoreleasepool {
        @synchronized (self) {
            if ([self isCancelled]) {
                return;
            }
            
            [self setExecuting:YES];
            
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
        }
        
        [self startRunLoop];
        
        [self setExecuting:NO];
        [self setFinished:YES];
    }
}

- (void)cancel
{
    @synchronized (self) {
        [super cancel];
        [_connection cancel];
        _connection = nil;
    }
    
    [self synchronizeIfNeeded];
}

- (void)startRunLoop
{
    _runLoop = CFRunLoopGetCurrent();
    CFRunLoopRun();
}

- (void)stopRunLoop
{
    if (_runLoop) {
        CFRunLoopStop(_runLoop);
        _runLoop = NULL;
    }
}

- (void)synchronizeIfNeeded
{
    @synchronized (self) {
        if ([_mutableData length] > 0) {
            [self.cacheFile writeData:_mutableData atOffset:_offset];
            _mutableData = nil;
        }
    }
    
    [self.cacheFile synchronize];
}

#pragma mark - NSURLConnectionDelegate && NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    [self synchronizeIfNeeded];
    [self stopRunLoop];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self synchronizeIfNeeded];
    [self stopRunLoop];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (nil == response || NO == [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    
    LLLog(@"didReceiveResponse: %@ <%@>", response, [NSThread currentThread]);
    
    [self.cacheFile receivedResponse:(NSHTTPURLResponse *)response forLoadingRequest:self.loadingRequest];
    
    if (NO == [(NSHTTPURLResponse *)response ll_supportRange]) {
        LLLog(@"[ERROR] not support range");
        _offset = 0;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.loadingRequest.dataRequest respondWithData:data];
    
    // save local
    @synchronized (self) {
        [_mutableData appendData:data];
        if (_mutableData.length >= MAX_MEM_SIZE) {
            [self.cacheFile writeData:_mutableData atOffset:_offset];
            _offset += [_mutableData length];
            _mutableData = [NSMutableData data];
        }
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    LLLog(@"[WRN] redirect... %@", response);
    
    if (response) {
        self.loadingRequest.redirect = request;
    }
    
    return request;
}

@end
