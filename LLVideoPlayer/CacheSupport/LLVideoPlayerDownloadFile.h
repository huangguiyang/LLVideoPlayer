//
//  LLVideoPlayerDownloadFile.h
//  Pods
//
//  Created by mario on 2017/7/25.
//
//

#import <Foundation/Foundation.h>

@interface LLVideoPlayerDownloadFile : NSObject

+ (instancetype)fileWithFilePath:(NSString *)filePath;

- (instancetype)initWithFilePath:(NSString *)filePath;

@property (nonatomic, strong, readonly) NSString *filePath;

- (void)removeCache;
- (BOOL)validateCache;

- (void)didReceivedResponse:(NSHTTPURLResponse *)response;
- (void)writeData:(NSData *)data atOffset:(NSUInteger)offset;

@end
