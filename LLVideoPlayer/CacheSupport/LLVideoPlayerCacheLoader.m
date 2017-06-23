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
#import "LLVideoPlayerCachePolicy.h"
#import "LLVideoPlayerInternal.h"
#import "NSString+LLVideoPlayer.h"
#import "LLVideoPlayerCacheOperation.h"

@interface LLVideoPlayerCacheLoader ()

@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation LLVideoPlayerCacheLoader

#pragma mark - Initialize

- (void)dealloc
{
    [self.operationQueue cancelAllOperations];
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
        self.cacheFile = [LLVideoPlayerCacheFile cacheFileWithFilePath:path cachePolicy:cachePolicy];
        self.operationQueue = [[NSOperationQueue alloc] init];
        [self.operationQueue setName:@"LLVideoPlayerCacheOperationQueue"];
        self.operationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    }
    return self;
}

#pragma mark - Private

- (void)startLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    LLVideoPlayerCacheOperation *operation = [LLVideoPlayerCacheOperation operationWithLoadingRequest:loadingRequest cacheFile:self.cacheFile];
    [self.operationQueue addOperation:operation];
}

- (void)cancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSArray *operations = [NSArray arrayWithArray:self.operationQueue.operations];
    for (LLVideoPlayerCacheOperation *operation in operations) {
        if (operation.loadingRequest == loadingRequest) {
            [operation cancel];
        }
    }
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    LLLog(@"[Comming] %@", LLLoadingRequestToString(loadingRequest));
    [self startLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    LLLog(@"[Cancel] %@", LLLoadingRequestToString(loadingRequest));
    [self cancelLoadingRequest:loadingRequest];
}

@end
