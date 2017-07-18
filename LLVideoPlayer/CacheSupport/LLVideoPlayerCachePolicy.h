//
//  LLVideoPlayerCachePolicy.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

@interface LLVideoPlayerCachePolicy : NSObject

+ (instancetype)defaultPolicy;

@property (nonatomic, assign) NSUInteger diskCapacity;   // in bytes
@property (nonatomic, assign) NSUInteger outdatedHours;  // in hours


@end
