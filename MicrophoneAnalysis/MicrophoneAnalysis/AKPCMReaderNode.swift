//
//  AKPCMReaderNode.swift
//  MicrophoneAnalysis
//
//  Created by jufan wang on 2020/10/24.
//  Copyright © 2020 AudioKit. All rights reserved.
//

import Foundation
import AudioKit
 
open class AKPCMReaderNode: AKNode, AKComponent, AKToggleable, AKInput {
    
//    #if TARGET_OS_IPHONE
//        mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
//    #elif TARGET_OS_MAC
//        mixerDescription.componentSubType = kAudioUnitSubType_StereoMixer;
//    #endif
    
//    appleEffect: kAudioUnitSubType_StereoMixer
    public typealias AKAudioUnitType = AKPCMAudioUnit
    public static var ComponentDescription = AudioComponentDescription(generator: "pcmr")
        
    public var _isStarted: Bool
    internal var internalAU: AKAudioUnitType?
    
    /// Tells whether the node is processing (ie. started, playing, or active)
    @objc open dynamic var isStarted: Bool {
        return _isStarted;
    }
    
    @objc public override init() {
        
        _Self.register()
        _isStarted = false;
        super.init()
        
        AVAudioUnit._instantiate(with: _Self.ComponentDescription) { [weak self] avAudioUnit in
            guard let strongSelf = self else {
                AKLog("Error: self is nil")
                return
            }
            strongSelf.internalAU = avAudioUnit.auAudioUnit as? AKAudioUnitType
            strongSelf.avAudioUnit = avAudioUnit
            strongSelf.avAudioNode = avAudioUnit
            strongSelf.start();
        }
          
        
        let url = Bundle.main.url(forResource: "in", withExtension: "pcm")
        let data = try! Data(contentsOf: url!)
        
        let interleavedFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                              sampleRate: 44100,
                                              channels: 2,
                                              interleaved:false)!

//            let interleavedBuffer = AVAudioPCMBuffer(pcmFormat: interleavedFormat, frameCapacity: UInt32(data.count) / interleavedFormat.streamDescription.pointee.mBytesPerFrame)
//

            let interleavedBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat: interleavedFormat, frameCapacity: AVAudioFrameCount(data.count/4))!

        interleavedBuffer.int16ChannelData!.pointee.withMemoryRebound(to: UInt8.self, capacity: data.count) {
                   let stream = OutputStream(toBuffer: $0, capacity: data.count)
                   stream.open()
                   _ = data.withUnsafeBytes {
                       stream.write($0, maxLength: data.count)
                   }
                   stream.close()
               }
        interleavedBuffer.frameLength = interleavedBuffer.frameCapacity
         
            
            let nonInterleavedFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                     sampleRate: 44100,
                                                     channels: 2,
                                                     interleaved: false)!
            let nonInterleavedBuffer = AVAudioPCMBuffer(pcmFormat: nonInterleavedFormat,
                                                        frameCapacity: interleavedBuffer.frameCapacity)!
            nonInterleavedBuffer.frameLength = interleavedBuffer.frameLength

            let converter = AVAudioConverter(from: interleavedFormat,
                                             to: nonInterleavedFormat)!
           try?  converter.convert(to: nonInterleavedBuffer,
                               from: interleavedBuffer)
        
        let blist: AudioBufferList = interleavedBuffer.audioBufferList.pointee
        let nonblist: AudioBufferList = nonInterleavedBuffer.audioBufferList.pointee

///return nonInterleavedBuffer
 
    }
    
    // MARK: - Control
    /// Function to start, play, or activate the node, all do the same thing
    @objc open func start() {
        internalAU?.start()
        _isStarted = true
    }

    /// Function to stop or bypass the node, both are equivalent
    @objc open func stop() {
        _isStarted = false;
        internalAU?.stop()
    }
     
    
}
