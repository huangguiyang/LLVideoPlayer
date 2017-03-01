//
//  LLPlayerItemRemoteCacheTask.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLPlayerItemCacheTask.h"

@interface LLPlayerItemRemoteCacheTask : LLPlayerItemCacheTask

@property (nonatomic, strong) NSHTTPURLResponse *response;

@end
