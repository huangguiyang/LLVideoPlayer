//
//  LLVideoPlayerRemoteCacheTask.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheTask.h"

@interface LLVideoPlayerRemoteCacheTask : LLVideoPlayerCacheTask

@property (nonatomic, strong) NSHTTPURLResponse *response;

@end
