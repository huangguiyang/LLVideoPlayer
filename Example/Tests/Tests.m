//
//  LLVideoPlayerTests.m
//  LLVideoPlayerTests
//
//  Created by mario on 12/23/2016.
//  Copyright (c) 2016 mario. All rights reserved.
//

@import XCTest;
#import <NSURL+LLVideoPlayer.h>

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

- (void)testCustomSchemeURL
{
    NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
    NSURL *url2 = [url ll_customSchemeURL];
    XCTAssert([url2.scheme isEqualToString:@"streaming"]);
    XCTAssert([url2.ll_originalSchemeURL isEqual:url]);
}

@end

