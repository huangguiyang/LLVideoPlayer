//
//  LLVideoPlayerDownloadFile.m
//  Pods
//
//  Created by mario on 2017/7/25.
//
//

#import "LLVideoPlayerDownloadFile.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSURLResponse+LLVideoPlayer.h"
#import "NSString+LLVideoPlayer.h"

#define kAllHeaderFieldsKey @"allHeaderFields"
#define kRangeKey @"range"

@interface LLVideoPlayerDownloadFile ()

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *indexPath;

@end

@implementation LLVideoPlayerDownloadFile

+ (NSString *)indexFileExtension
{
    return @".idx";
}

+ (instancetype)fileWithFilePath:(NSString *)filePath
{
    return [[self alloc] initWithFilePath:filePath];
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        NSString *dir = [filePath stringByDeletingLastPathComponent];
        
        // check directory
        [LLVideoPlayerDownloadFile checkCacheDirectory:dir];
        
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:dir] &&
            NO == [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]) {
            return nil;
        }
        
        self.filePath = filePath;
        self.indexPath = [filePath stringByAppendingString:[[self class] indexFileExtension]];
    }
    return self;
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
            return nil;
        }
        
        NSRange range = [allHeaderFields[@"Content-Range"] ll_decodeRangeFromContentRange];
        if (NO == LLValidByteRange(range)) {
            return nil;
        }
        
        NSData *data = [NSData dataWithContentsOfFile:self.filePath];
        if (nil == data || data.length != range.length) {
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

#pragma mark - Private

+ (void)checkCacheDirectory:(NSString *)directory
{
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:directory]) {
        return;
    }
    
    NSError *error;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:&error];
    if (error) {
        return;
    }
    
    NSDate *now = [NSDate date];
    
    for (NSString *name in contents) {
        if ([name hasSuffix:[[self class] indexFileExtension]]) {
            continue;
        }
        
        NSString *path = [directory stringByAppendingPathComponent:name];
        error = nil;
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        if (error) {
            continue;
        }
        if (NO == [[attr fileType] isEqualToString:NSFileTypeRegular]) {
            continue;
        }
        
        NSDate *date = [attr fileCreationDate];
        NSInteger days = [now timeIntervalSinceDate:date] / (3600 * 24);
        if (days >= 7) {
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            NSString *index = [path stringByAppendingString:[self indexFileExtension]];
            [[NSFileManager defaultManager] removeItemAtPath:index error:nil];
        }
    }
}

@end
