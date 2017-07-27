//
//  LLVideoPlayerDownloadFile.m
//  Pods
//
//  Created by mario on 2017/7/25.
//
//

#import "LLVideoPlayerDownloadFile.h"
#import "LLVideoPlayerInternal.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "NSString+LLVideoPlayer.h"

#define kAllHeaderFieldsKey @"allHeaderFields"
#define kRangeKey @"range"

@interface LLVideoPlayerDownloadFile ()

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *indexPath;
@property (nonatomic, strong) NSString *lockPath;

@end

@implementation LLVideoPlayerDownloadFile

+ (instancetype)fileWithFilePath:(NSString *)filePath
{
    return [[self alloc] initWithFilePath:filePath];
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        NSString *dir = [filePath stringByDeletingLastPathComponent];
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:dir] &&
            NO == [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]) {
            LLLog(@"[ERROR] Cannot create cache directory: %@", dir);
            return nil;
        }
        
        self.filePath = filePath;
        self.indexPath = [filePath stringByAppendingString:@".idx"];
        self.lockPath = [filePath stringByAppendingString:@".lock"];
        LLLog(@"DownloadFile: %@", self.filePath);
    }
    return self;
}

- (void)lock
{
    if (NO == [[NSFileManager defaultManager] createFileAtPath:self.lockPath contents:nil attributes:nil]) {
        LLLog(@"[ERROR] can't create lock file");
    }
}

- (void)unlock
{
    if (NO == [[NSFileManager defaultManager] removeItemAtPath:self.lockPath error:nil]) {
        LLLog(@"[ERROR] can't remove lock file");
    }
}

- (BOOL)isLocked
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.lockPath];
}

- (void)removeCache
{
    [[NSFileManager defaultManager] removeItemAtPath:self.indexPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
}

- (BOOL)validateCache
{
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:self.indexPath]) {
        return NO;
    }
    
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
        return NO;
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:self.indexPath];
    NSDictionary *allHeaderFields = dict[kAllHeaderFieldsKey];
    if (nil == dict || nil == allHeaderFields) {
        LLLog(@"[ERROR] dict empty: %@", dict);
        return NO;
    }
    
    NSRange range = [allHeaderFields[@"Content-Range"] ll_decodeRangeFromContentRange];
    if (range.location == NSNotFound) {
        LLLog(@"[ERROR] decode error");
        return NO;
    }
    
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:nil];
    long long fileSize = [attr[NSFileSize] longLongValue];
    
    if (range.length != fileSize) {
        LLLog(@"size not equal");
        return NO;
    }
    
    return YES;
}

- (void)didReceivedResponse:(NSHTTPURLResponse *)response
{
    NSDictionary *dict = @{kAllHeaderFieldsKey: response.allHeaderFields};
    [dict writeToFile:self.indexPath atomically:YES];
}

- (void)writeData:(NSData *)data atOffset:(NSUInteger)offset
{
    [data writeToFile:self.filePath atomically:YES];
}

@end
