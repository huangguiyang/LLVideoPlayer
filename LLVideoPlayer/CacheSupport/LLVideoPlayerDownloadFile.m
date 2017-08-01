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
    }
    return self;
}

- (void)removeCache
{
    [[NSFileManager defaultManager] removeItemAtPath:self.indexPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
}

- (NSDictionary *)doReadCache
{
    @synchronized (self) {
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:self.indexPath] ||
            NO == [[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
            return nil;
        }
        
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:self.indexPath];
        NSDictionary *allHeaderFields = dict[kAllHeaderFieldsKey];
        if (nil == dict || nil == allHeaderFields) {
            LLLog(@"[ERROR] dict empty: %@", dict);
            return nil;
        }
        
        NSRange range = [allHeaderFields[@"Content-Range"] ll_decodeRangeFromContentRange];
        if (NO == LLValidByteRange(range)) {
            LLLog(@"[ERROR] decode error");
            return nil;
        }
        
        NSData *data = [NSData dataWithContentsOfFile:self.filePath];
        if (nil == data || data.length != range.length) {
            LLLog(@"size not equal");
            return nil;
        }
        
        return @{@"headers": allHeaderFields, @"data": data, @"range": NSStringFromRange(range)};
    }
}

- (BOOL)validateCache
{
    return [self doReadCache] != nil;
}

- (NSDictionary *)readCache
{
    return [self doReadCache];
}

- (void)didReceivedResponse:(NSHTTPURLResponse *)response
{
    @synchronized (self) {
        NSDictionary *dict = @{kAllHeaderFieldsKey: response.allHeaderFields};
        [dict writeToFile:self.indexPath atomically:YES];
    }
}

- (void)writeData:(NSData *)data atOffset:(NSUInteger)offset
{
    @synchronized (self) {
        [data writeToFile:self.filePath atomically:YES];
    }
}

@end
