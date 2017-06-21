//
//  LLVideoPlayerCacheRemoteTask.m
//  Pods
//
//  Created by mario on 2017/6/9.
//
//

#import "LLVideoPlayerCacheRemoteTask.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "LLVideoPlayerInternal.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"

@interface LLVideoPlayerCacheRemoteTask () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) NSInteger length;

@end

@implementation LLVideoPlayerCacheRemoteTask

- (void)dealloc
{
    [self.connection cancel];
}

- (void)resume
{
    [super resume];
    
    NSMutableURLRequest *request = [self.loadingRequest.request mutableCopy];
    request.URL = [self.loadingRequest.request.URL ll_originalSchemeURL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;  // very important
    self.offset = 0;
    self.length = 0;
    
    NSString *rangeString = LLRangeToHTTPRangeHeader(self.range);
    if (rangeString) {
        [request setValue:rangeString forHTTPHeaderField:@"Range"];
        self.offset = self.range.location;
        self.length = self.range.length;
    }
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection start];
}

- (void)cancel
{
    [self.connection cancel];
    self.connection = nil;
    [super cancel];
}

- (void)synchronizeIfNeeded
{
    [self.cacheFile synchronize];
}

#pragma mark - NSURLConnectionDelegate && NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    LLLog(@"didFailWithError: %@, %p", error, self);
    [self synchronizeIfNeeded];
    
    if ([self.delegate respondsToSelector:@selector(task:didCompleteWithError:)]) {
        [self.delegate task:self didCompleteWithError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    LLLog(@"connectionDidFinishLoading: %@, %p", NSStringFromRange(self.range), self);
    [self synchronizeIfNeeded];
    
    if ([self.delegate respondsToSelector:@selector(task:didCompleteWithError:)]) {
        [self.delegate task:self didCompleteWithError:nil];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (nil == response || NO == [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    
    LLLog(@"didReceiveResponse: %@", response);
    [self.cacheFile receivedResponse:(NSHTTPURLResponse *)response forLoadingRequest:self.loadingRequest];
    
    if (NO == [(NSHTTPURLResponse *)response ll_supportRange]) {
        self.offset = 0;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.loadingRequest.dataRequest respondWithData:data];
    
    // save local
    [self.cacheFile writeData:data atOffset:self.offset];
    self.offset += [data length];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response) {
        self.loadingRequest.redirect = request;
    }
    
    return request;
}

@end
