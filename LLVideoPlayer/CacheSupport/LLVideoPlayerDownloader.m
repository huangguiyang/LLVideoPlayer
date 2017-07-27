//
//  LLVideoPlayerPreloader.m
//  Pods
//
//  Created by mario on 2017/7/21.
//
//

#import "LLVideoPlayerDownloader.h"
#import "LLVideoPlayerDownloadFile.h"
#import "NSString+LLVideoPlayer.h"
#import "LLVideoPlayerInternal.h"
#import "LLVideoPlayerDownloadOperation.h"

@interface LLVideoPlayerDownloader ()

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation LLVideoPlayerDownloader

+ (NSString *)cacheDirectory
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cache stringByAppendingPathComponent:@"LLVideoPlayer.preload"];
}

+ (instancetype)defaultDownloader
{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)dealloc
{
    [self.operationQueue cancelAllOperations];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        [self.operationQueue setName:@"LLVideoPlayerDownloaderOperationQueue"];
        if ([self.operationQueue respondsToSelector:@selector(setQualityOfService:)]) {
            self.operationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        }
        self.operationQueue.maxConcurrentOperationCount = 3;
    }
    return self;
}

+ (LLVideoPlayerDownloadFile *)downloadFileWithURL:(NSURL *)url
{
    if (nil == url || url.absoluteString.length == 0) {
        return nil;
    }
    
    NSString *name = [url.absoluteString ll_md5];
    NSString *path = [[self cacheDirectory] stringByAppendingPathComponent:name];
    return [[LLVideoPlayerDownloadFile alloc] initWithFilePath:path];
}

- (void)preloadWithURL:(NSURL *)url
{
    LLVideoPlayerDownloadFile *file = [LLVideoPlayerDownloader downloadFileWithURL:url];
    if (nil == file) {
        LLLog(@"[ERROR] can't create cache file");
        return;
    }
    LLVideoPlayerDownloadOperation *operation = [[LLVideoPlayerDownloadOperation alloc] initWithURL:url downloadFile:file];
    [self.operationQueue addOperation:operation];
}

- (void)cancelWithURL:(NSURL *)url
{
    NSArray *operations = self.operationQueue.operations;
    for (LLVideoPlayerDownloadOperation *operation in operations) {
        if ([operation.url isEqual:url]) {
            [operation cancel];
        }
    }
}

- (void)cancelAllPreloads
{
    [self.operationQueue cancelAllOperations];
}

@end
