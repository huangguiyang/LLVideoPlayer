//
//  LLVideoPlayerCacheFile.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

@interface LLVideoPlayerCacheFile : NSObject

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath;

- (instancetype)initWithFilePath:(NSString *)filePath;

- (BOOL)saveData:(NSData *)data offset:(NSInteger)offset flags:(NSInteger)flags;

- (NSData *)dataWithRange:(NSRange)range;

@end
