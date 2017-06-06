//
//  LLViewController.m
//  LLVideoPlayer
//
//  Created by mario on 12/23/2016.
//  Copyright (c) 2016 mario. All rights reserved.
//

#import "LLViewController.h"
#import "LLVideoPlayer.h"
#import "Masonry.h"

@interface LLViewController () <LLVideoPlayerDelegate>

@property (nonatomic, strong) LLVideoPlayer *player;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *totalTimeLabel;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UISwitch *cacheSwitch;

@end

@implementation LLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    BOOL cacheSupport = YES;
    
    self.player = [[LLVideoPlayer alloc] init];
    [self.view addSubview:self.player.view];
    self.player.view.frame = CGRectMake(10, 80, 300, 200);
    self.player.delegate = self;
    self.player.cacheSupportEnabled = cacheSupport;
    
    {
        self.cacheSwitch = [UISwitch new];
        [self.view addSubview:self.cacheSwitch];
        self.cacheSwitch.frame = CGRectMake(10, 30, self.cacheSwitch.frame.size.width, self.cacheSwitch.frame.size.height);
        self.cacheSwitch.on = cacheSupport;
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"force play" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(100, 30, 80, 40);
        [button addTarget:self action:@selector(forcePlayAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        self.stateLabel = [UILabel new];
        self.stateLabel.backgroundColor = [UIColor clearColor];
        self.stateLabel.font = [UIFont systemFontOfSize:14];
        self.stateLabel.textColor = [UIColor redColor];
        [self.view addSubview:self.stateLabel];
        self.stateLabel.frame = CGRectMake(10, 300, 300, 20);
        
        self.stateLabel.text = [LLVideoPlayerHelper playerStateToString:self.player.state];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"load" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(10, 340, 50, 40);
        [button addTarget:self action:@selector(loadAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"play" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(70, 340, 50, 40);
        [button addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"pause" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(130, 340, 50, 40);
        [button addTarget:self action:@selector(pauseAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"dismiss" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(190, 340, 60, 40);
        [button addTarget:self action:@selector(dismissAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        self.currentTimeLabel = [UILabel new];
        self.currentTimeLabel.backgroundColor = [UIColor clearColor];
        self.currentTimeLabel.font = [UIFont systemFontOfSize:14];
        [self.view addSubview:self.currentTimeLabel];
        self.currentTimeLabel.frame = CGRectMake(10, 400, 60, 30);
        
        self.slider = [[UISlider alloc] init];
        [self.view addSubview:self.slider];
        self.slider.frame = CGRectMake(60, 405, 200, 20);
        [self.slider addTarget:self action:@selector(sliderTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        
        self.totalTimeLabel = [UILabel new];
        self.totalTimeLabel.backgroundColor = [UIColor clearColor];
        self.totalTimeLabel.font = [UIFont systemFontOfSize:14];
        [self.view addSubview:self.totalTimeLabel];
        self.totalTimeLabel.frame = CGRectMake(270, 400, 60, 30);
        
        self.currentTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:0];
        self.totalTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:0];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadAction:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://baobab.wdjcdn.com/1456665467509qingshu.mp4"];
    self.player.cacheSupportEnabled = self.cacheSwitch.on;
    [self.player loadVideoWithStreamURL:url];
    //    LLVideoTrack *track = [[LLVideoTrack alloc] initWithStreamURL:url];
    //    track.lastWatchedDuration = @(40);
    //    [self.player loadVideoWithTrack:track];
}

- (void)playAction:(id)sender
{
    [self.player playContent];
}

- (void)pauseAction:(id)sender
{
    [self.player pauseContent];
}

- (void)dismissAction:(id)sender
{
    [self.player dismissContent];
}

- (void)sliderTouchUpInside:(UISlider *)sender
{
    float sec = [self.player.track.totalDuration floatValue] * sender.value;
    
    [self.player seekToTimeInSecond:sec userAction:YES completionHandler:nil];
}

- (void)forcePlayAction:(id)sender
{
    self.player.state = LLVideoPlayerStateContentPlaying;
}

#pragma mark - LLVideoPlayerDelegate

#pragma mark - State Changed
- (BOOL)shouldVideoPlayer:(LLVideoPlayer *)videoPlayer changeStateTo:(LLVideoPlayerState)state
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    return YES;
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willChangeStateTo:(LLVideoPlayerState)state
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didChangeStateFrom:(LLVideoPlayerState)state
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.stateLabel.text = [LLVideoPlayerHelper playerStateToString:self.player.state];
}

#pragma mark - Play Control
- (BOOL)shouldVideoPlayer:(LLVideoPlayer *)videoPlayer startVideo:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    return YES;
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willStartVideo:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didStartVideo:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.totalTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:[track.totalDuration floatValue]];
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didPlayFrame:(LLVideoTrack *)track time:(NSTimeInterval)time
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.currentTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:time];
    self.totalTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:[track.totalDuration floatValue]];
    self.slider.value = time / [track.totalDuration doubleValue];
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didPlayToEnd:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

#pragma mark - Error
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didFailWithError:(NSError *)error track:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

@end
