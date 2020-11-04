//
//  AKPCMAudioUnit.m
//  MicrophoneAnalysis
//
//  Created by jufan wang on 2020/10/24.
//  Copyright © 2020 AudioKit. All rights reserved.
//

#import "AKPCMAudioUnit.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioKit/AudioKit.h>
#import <AudioUnit/AudioUnit.h>

#import "TMEBufferedAudioBus.hpp"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

typedef struct {
//    char            riffType[4];    //4byte,资源交换文件标志:RIFF
//    unsigned int    riffSize;       //4byte,从下个地址到文件结尾的总字节数
//    char            wavType[4]; //4byte,wav文件标志:WAVE
//    char            formatType[4];  //4byte,波形文件标志:FMT(最后一位空格符)
//    unsigned int    formatSize;     //4byte,音频属性(compressionCode,numChannels,sampleRate,bytesPerSecond,blockAlign,bitsPerSample)所占字节数
//    unsigned short  compressionCode;//2byte,格式种类(1-线性pcm-WAVE_FORMAT_PCM,WAVEFORMAT_ADPCM)
//    unsigned short  numChannels;    //2byte,通道数
//    unsigned int    sampleRate;     //4byte,采样率
//    unsigned int    bytesPerSecond; //4byte,传输速率          ??????
//    unsigned short  blockAlign;     //2byte,数据块的对齐，即DATA数据块长度   ??????
//    unsigned short  bitsPerSample;  //2byte,采样精度-PCM位宽   16
//    char            dataType[4];    //4byte,数据标志:data
//    unsigned int    dataSize;       //4byte,从下个地址到文件结尾的总字节数，即除了wav header以外的pcm data length
} head_data_t;

//2   16  44100  sumlength
NSData * pcmAddWavHeader(int channels, int longSampleRate, int totalDataLen) {
    Byte  header[44];
     
    int ByteRate = 2*16*44100/8;
    short BlockAlign = 2*16/8;
     
//    riffType[4];    //4byte,资源交换文件标志:RIFF
    header[0] = 'R';  // RIFF/WAVE header
    header[1] = 'I';
    header[2] = 'F';
    header[3] = 'F';
//    riffSize;       //4byte,从下个地址到文件结尾的总字节数
    int totalDataLen1 = totalDataLen + 44 - 8;
    header[4] = (Byte) (totalDataLen1 & 0xff);  //file-size (equals file-size - 8)
    header[5] = (Byte) ((totalDataLen1 >> 8) & 0xff);
    header[6] = (Byte) ((totalDataLen1 >> 16) & 0xff);
    header[7] = (Byte) ((totalDataLen1 >> 24) & 0xff);
    
//    wavType[4]; //4byte,wav文件标志:WAVE
    header[8] = 'W';  // Mark it as type "WAVE"
    header[9] = 'A';
    header[10] = 'V';
    header[11] = 'E';
//    formatType[4];  //4byte,波形文件标志:FMT(最后一位空格符)
    header[12] = 'f';  // Mark the format section 'fmt ' chunk
    header[13] = 'm';
    header[14] = 't';
    header[15] = ' ';
    
//    formatSize;
    header[16] = 16;   // 4 bytes: size of 'fmt ' chunk, Length of format data.  Always 16
    header[17] = 0;
    header[18] = 0;
    header[19] = 0;
        
//    compressionCode;//2byte,格式种类(1-线性pcm-WAVE_FORMAT_PCM,WAVEFORMAT_ADPCM)
    header[20] = 1;  // format = 1 ,Wave type PCM
    header[21] = 0;
    
//    numChannels;    //2byte,通道数
    header[22] = (Byte) channels;  // channels
    header[23] = 0;
//    sampleRate;     //4byte,采样率
    header[24] = (Byte) (longSampleRate & 0xff);
    header[25] = (Byte) ((longSampleRate >> 8) & 0xff);
    header[26] = (Byte) ((longSampleRate >> 16) & 0xff);
    header[27] = (Byte) ((longSampleRate >> 24) & 0xff);
    
//    bytesPerSecond; //4byte,传输速率   ???????
    int byteRate = ByteRate;
    header[28] = (Byte) (byteRate & 0xff);
    header[29] = (Byte) ((byteRate >> 8) & 0xff);
    header[30] = (Byte) ((byteRate >> 16) & 0xff);
    header[31] = (Byte) ((byteRate >> 24) & 0xff);
    
//    blockAlign;     //2byte,数据块的对齐，即DATA数据块长度   ???????
    header[32] = (Byte) (BlockAlign); // block align
    header[33] = 0;
    
//    bitsPerSample;  //2byte,采样精度-PCM位宽
    header[34] = 16; // bits per sample  ??
    header[35] = 0;
    
//    dataType[4];    //4byte,数据标志:data
    header[36] = 'd'; //"data" marker
    header[37] = 'a';
    header[38] = 't';
    header[39] = 'a';
    
//    dataSize;       //4byte,从下个地址到文件结尾的总字节数，即除了wav header以外的pcm data length
    header[40] = (Byte) (totalDataLen & 0xff);  //data-size (equals file-size - 44).
    header[41] = (Byte) ((totalDataLen >> 8) & 0xff);
    header[42] = (Byte) ((totalDataLen >> 16) & 0xff);
    header[43] = (Byte) ((totalDataLen >> 24) & 0xff);
    return [[NSData alloc] initWithBytes:header length:44];;
}
 
void pcmtowav() {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"in" withExtension:@"pcm"];        
    NSData * audioData = [NSData dataWithContentsOfURL:url];
    NSData *header = pcmAddWavHeader(2, 44100, audioData.length);
    NSMutableData *wavDatas = [[NSMutableData alloc]init];
    [wavDatas appendData:header];
    [wavDatas appendData:audioData];
}

//https://github.com/AudioKit/AudioKit/issues/1241
//    https://stackoverflow.com/questions/27250317/avaudioengine-playing-multi-channel-audio
//https://archive.codeplex.com/?p=audiotestfiles

@interface AKPCMAudioUnit() {
    TMEBufferedAudioBus _inputBus;
    TMEBufferedAudioBus _inputBus2;
    TMEBufferedAudioBus _outputBus;
    TMEBufferedAudioBus _outputBus2;
}

@property (nonatomic, strong) NSInputStream * inputSteam;

@end

@implementation AKPCMAudioUnit

//AudioStreamBasicDescription outputFormat;
//memset(&outputFormat, 0, sizeof(outputFormat));
//outputFormat.mSampleRate       = 44100; // 采样率
//outputFormat.mFormatID         = kAudioFormatLinearPCM; // PCM格式
//outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger; // 整形
//outputFormat.mFramesPerPacket  = 1; // 每帧只有1个packet
//outputFormat.mChannelsPerFrame = 2; // 声道数
//outputFormat.mBytesPerFrame    = 2; // 每帧只有2个byte 声道*位深*Packet数
//outputFormat.mBytesPerPacket   = 2; // 每个Packet只有2个byte
//outputFormat.mBitsPerChannel   = 16; // 位深

@synthesize parameterTree = _parameterTree;
@synthesize defaultFormat = _defaultFormat;

- (AVAudioFormat *)defaultFormat {
    //channels == 2
    //AVAudioPCMFormatFloat32 yes
    //其它都失败
    if (!_defaultFormat) {
        _defaultFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:44100 channels:2 interleaved:false];
    }
    return _defaultFormat;
}
- (void)createParameters {
//    standardSetup(Tester)
    self.rampDuration = 0.0002;
    
    
    
//    AVAudioChannelLayout *chLayout = [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_UseChannelDescriptions];
//    self.defaultFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:44100 interleaved:false channelLayout:chLayout];
//    self.defaultFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:false];
//    self.defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    
//    NSError *error;
//    [[AUAudioUnitBus alloc] initWithFormat:self.defaultFormat error:&error];

    _inputBus.init(self.defaultFormat, 8);
    _inputBus2.init(self.defaultFormat, 8);
    _inputBus.bus.shouldAllocateBuffer = NO;
    _inputBus2.bus.shouldAllocateBuffer = NO;
    self.inputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                      busType:AUAudioUnitBusTypeInput
                                                       busses:@[_inputBus.bus, _inputBus2.bus]];
    
    _parameterTree = [AUParameterTree treeWithChildren:@[]];
    
    // Create the output busses.
    _outputBus.init(self.defaultFormat, 8);
    _outputBus2.init(self.defaultFormat, 8);
    _outputBus.bus.shouldAllocateBuffer = NO;
    _outputBus2.bus.shouldAllocateBuffer = NO;
    self.outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_outputBus.bus, _outputBus2.bus]];
    
//    parameterTreeBlock(Tester)
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];

    if (self == nil) {
        return nil;
    }
 
    [self createParameters];

    return self;
}

//- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
//    if (![super allocateRenderResourcesAndReturnError:outError]) {
//        return NO;
//    }
//    self.outputBusBuffer.allocateRenderResources(self.maximumFramesToRender);
//    return YES;
//}
//

//- (void)deallocateRenderResources {
//    _outputBusBuffer.deallocateRenderResources();
//    [super deallocateRenderResources];
//}

//// Create the output busses.
//self.outputBus = [[AUAudioUnitBus alloc] initWithFormat:self.defaultFormat error:nil];
//_outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
//                                                         busType:AUAudioUnitBusTypeOutput
//                                                          busses: @[self.outputBus]];

- (AUInternalRenderBlock)internalRenderBlock {
    __weak typeof(self) wself = self;
    
    __block int numSamples = 512;
    __block int len16 = numSamples * sizeof(short);
    short *samples = (short *)malloc(len16 * 2);
//    short *samplesOne = (short *)malloc(len16);
    short *samplesTwo = (short *)malloc(len16);
    __block int len32f = numSamples * sizeof(float);
    float *convertedSamples = (float *)malloc(len32f);
    float div = 32767.0;// normalize to -1.0/1.0 range
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        
        __strong typeof(wself) sself = wself;
        UInt32 size = (UInt32)[sself.inputSteam read:(uint8_t *)samples
                                        maxLength:len16 * 2];
        
        if (size != len16 * 2) {
            for(int i = 0; i < outputData->mNumberBuffers; i++) {
                memset(outputData->mBuffers[i].mData, 0, len32f);
            }
            return noErr;
        }
        
        int rindex = 0;
        for(int j = 0; j < size; ) {
            samples[rindex] = samples[j++];
            samplesTwo[rindex] = samples[j++];
            rindex++;
        }
        
        vDSP_vflt16(samples, 1, convertedSamples, 1, numSamples);
        vDSP_vsdiv(convertedSamples, 1, &div, convertedSamples, 1, numSamples);
        memcpy(outputData->mBuffers[0].mData, convertedSamples, len32f);
        
        vDSP_vflt16(samplesTwo, 1, convertedSamples, 1, numSamples);
        vDSP_vsdiv(convertedSamples, 1, &div, convertedSamples, 1, numSamples);
        memcpy(outputData->mBuffers[1].mData, convertedSamples, len32f);
        
        return noErr;
    };
}

//private func conterPCMInt16ToFloat32() -> AVAudioPCMBuffer {
//
//        let data = Data(bytes: rawBuffer,
//                        count: datalenInShort * MemoryLayout<Int16>.size)
//
//        let interleavedFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
//                                              sampleRate: WBDConstants.sampleRate,
//                                              channels: 2,
//                                              interleaved: true)!
//        let interleavedBuffer = data.toPCMBuffer(format: interleavedFormat)!
//
//        let nonInterleavedFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
//                                                 sampleRate: WBDConstants.sampleRate,
//                                                 channels: 2,
//                                                 interleaved: false)!
//        let nonInterleavedBuffer = AVAudioPCMBuffer(pcmFormat: nonInterleavedFormat,
//                                                    frameCapacity: interleavedBuffer.frameCapacity)!
//        nonInterleavedBuffer.frameLength = interleavedBuffer.frameLength
//
//        let converter = AVAudioConverter(from: interleavedFormat,
//                                         to: nonInterleavedFormat)!
//        try! converter.convert(to: nonInterleavedBuffer,
//                               from: interleavedBuffer)

//        return nonInterleavedBuffer
//    }

//NSURL *url = [[NSBundle mainBundle] URLForResource:@"in" withExtension:@"pcm"];
//NSData *data = [NSData dataWithContentsOfURL:url];


- (void)deallocateRenderResources {
    [super deallocateRenderResources];
    _inputBus.deallocateRenderResources();
}

- (void)start {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"in" withExtension:@"pcm"];
    
//    AVAudioChannelLayout *chLayout = [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_Stereo];
//    AVAudioFormat *chFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
//                                                              sampleRate:44100.0
//                                                              interleaved:NO
//                                                            channelLayout:chLayout];
//
//    AVAudioPCMBuffer *thePCMBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:chFormat frameCapacity:1323000 * 2];
//    thePCMBuffer.frameLength = thePCMBuffer.frameCapacity;
//
//    // 初始化数据区
//    for (AVAudioChannelCount ch = 0; ch < chFormat.channelCount; ++ch) {
//        memset(thePCMBuffer.int16ChannelData[ch], 'F', thePCMBuffer.frameLength * chFormat.streamDescription->mBytesPerFrame);
//    }
//    const AudioBufferList * wwaudioBufferList = [thePCMBuffer audioBufferList];
//    NSData * audioData = [NSData dataWithContentsOfURL:url];
//    [audioData getBytes:thePCMBuffer.int16ChannelData[0] length:audioData.length];
//    const AudioBufferList * wwdaudioBufferList = thePCMBuffer.audioBufferList;
//
    
//    pcmBuffer.int16ChannelData =
    
    self.inputSteam = [NSInputStream inputStreamWithURL:url];
         
    if (!self.inputSteam) {
        NSLog(@"打开文件失败 %@", url);
    } else {
        [self.inputSteam open];
    }    
}

- (void)stop {
    [self.inputSteam close];
}
 

@end

