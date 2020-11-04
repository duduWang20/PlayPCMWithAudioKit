//
//  AKPCMAudioUnit.h
//  MicrophoneAnalysis
//
//  Created by jufan wang on 2020/10/24.
//  Copyright © 2020 AudioKit. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioKit/AudioKit.h>

//AudioKit-4.11.2 h

//目前一共尝试了三种方法：
//1 使用底层 audio unit ，比较简单，但其channel === 1时 可以正常播放钢琴曲 ；
//2 使用 audio uint + player 的方式，没有成功，直接崩溃（具体原因不清，估计得改造 player ）；
//3 自定义 node ，使用 AKManager.output 播放。这种方式流程成功了 但是杂音很大 原来的钢琴音也受到较大的污染，但channel 始终是 1 无法调整为 2， 且设置 channel为 1时效果比2时好很多。代码是channel 设置为1时的情形。 使用 test.pcm测试， channel为 1时 只是多了杂音。

//#pragma once
//#import "AKAudioUnit.h"

NS_ASSUME_NONNULL_BEGIN

@interface AKPCMAudioUnit : AKAudioUnit

@end

NS_ASSUME_NONNULL_END
