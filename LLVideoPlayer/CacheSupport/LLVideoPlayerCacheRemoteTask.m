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
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "LLVideoPlayerInternal.h"

@interface LLVideoPlayerCacheRemoteTask () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;

@end

@implementation LLVideoPlayerCacheRemoteTask

- (void)dealloc
{
    LLLog(@"LLVideoPlayerCacheRemoteTask dealloc: %p", self);
    [self.connection cancel];
}

- (void)resume
{
    NSMutableURLRequest *request = [self.loadingRequest.request mutableCopy];
    request.URL = [self.loadingRequest.request.URL ll_originalSchemeURL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;  // very important
    
    NSString *rangeString = LLRangeToHTTPRangeHeader(self.range);
    [request setValue:rangeString forHTTPHeaderField:@"Range"];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection start];
}

- (void)cancel
{
    [self.connection cancel];
    self.connection = nil;
    [super cancel];
}

#pragma mark - NSURLConnectionDelegate && NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    LLLog(@"didFailWithError: %@, %p", error, self);
    if (self.completionBlock) {
        self.completionBlock(self, error);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    LLLog(@"connectionDidFinishLoading: %@, %p", NSStringFromRange(self.range), self);
    if (self.completionBlock) {
        self.completionBlock(self, nil);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    LLLog(@"didReceiveResponse: %@, %p", response, self);
    if (self.didReceiveResponseBlock) {
        self.didReceiveResponseBlock(self, response);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.loadingRequest.dataRequest respondWithData:data];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response) {
        self.loadingRequest.redirect = request;
    }
    
    return request;
}

@end
