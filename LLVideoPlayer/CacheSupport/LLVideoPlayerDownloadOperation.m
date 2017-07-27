//
//  LLVideoPlayerDownloadOperation.m
//  Pods
//
//  Created by mario on 2017/7/26.
//
//

#import "LLVideoPlayerDownloadOperation.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "LLVideoPlayerInternal.h"
#import "LLVideoPlayerCacheUtils.h"

@interface LLVideoPlayerDownloadOperation () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    NSURLConnection *_connection;
    NSMutableData *_mutableData;
    CFRunLoopRef _runloop;
}

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) LLVideoPlayerDownloadFile *downloadFile;

@end

@implementation LLVideoPlayerDownloadOperation

- (void)dealloc
{
    [_connection cancel];
}

+ (instancetype)operationWithURL:(NSURL *)url downloadFile:(LLVideoPlayerDownloadFile *)downloadFile
{
    return [[self alloc] initWithURL:url downloadFile:downloadFile];
}

- (instancetype)initWithURL:(NSURL *)url downloadFile:(LLVideoPlayerDownloadFile *)downloadFile
{
    self = [super init];
    if (self) {
        self.url = url;
        self.downloadFile = downloadFile;
    }
    return self;
}

- (void)main
{
    @autoreleasepool {
        if ([self isCancelled]) {
            return;
        }
        
        [self setExecuting:YES];
        
        if (NO == [self.downloadFile validateCache]) {
            // start
            [self startRequest];
            [self startRunLoop];
        }
        
        [self setExecuting:NO];
        [self setFinished:YES];
    }
}

- (void)cancel
{
    [super cancel];
}

- (void)startRunLoop
{
    _runloop = CFRunLoopGetCurrent();
    CFRunLoopRun();
}

- (void)stopRunLoop
{
    if (_runloop) {
        CFRunLoopStop(_runloop);
        _runloop = NULL;
    }
}

- (void)startRequest
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
    NSRange range = NSMakeRange(0, 1444);
    NSString *rangeString = LLRangeToHTTPRangeHeader(range);
    [request setValue:rangeString forHTTPHeaderField:@"Range"];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_connection start];
}

- (void)failWithError:(NSError *)error
{
    LLLog(@"[FAILED] %@", error);
    self.error = error;
    [self stopRunLoop];
}

#pragma mark - NSURLConnectionDelegate & NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    LLLog(@"[RESPONSE] %@", response);
    
    if (nil == response || NO == [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    
    if (NO == [(NSHTTPURLResponse *)response ll_supportRange]) {
        [connection cancel];
        [self failWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey: @"Range not supported."}]];
        return;
    }
    
    [self.downloadFile didReceivedResponse:(NSHTTPURLResponse *)response];
    _mutableData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_mutableData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    LLLog(@"[SUCCESS] %lu bytes", _mutableData.length);
    [self.downloadFile writeData:_mutableData atOffset:0];
    [self stopRunLoop];
}

@end
