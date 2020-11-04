//
//  ViewController.swift
//  MicrophoneAnalysis
//
//  Created by Kanstantsin Linou, revision history on Githbub.
//  Copyright © 2018 AudioKit. All rights reserved.
//

import AudioKit
import AudioKitUI
import Cocoa

class ViewController: NSViewController {
    
    var player: AKPlayer!
    

    @IBOutlet private var frequencyLabel: NSTextField!
    @IBOutlet private var amplitudeLabel: NSTextField!
    @IBOutlet private var noteNameWithSharpsLabel: NSTextField!
    @IBOutlet private var noteNameWithFlatsLabel: NSTextField!
    @IBOutlet private var audioInputPlot: EZAudioPlot!

//    var mic: AKMicrophone!
    
    var pcmreader: AKPCMReaderNode!
    var tracker: AKFrequencyTracker!
//    var silence: AKBooster!
    
    let noteFrequencies = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
    let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

    func setupPlot() {
//        let plot = AKNodeOutputPlot(pcmreader, frame: audioInputPlot.bounds)
//        plot.plotType = .rolling
//        plot.shouldFill = true
//        plot.shouldMirror = true
//        plot.color = NSColor.blue
//        plot.autoresizingMask = NSView.AutoresizingMask.width
//        audioInputPlot.addSubview(plot)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
//        AudioStreamBasicDescription outputFormat;
//        memset(&outputFormat, 0, sizeof(outputFormat));
//        outputFormat.mSampleRate       = 44100; // 采样率
//        outputFormat.mFormatID         = kAudioFormatLinearPCM; // PCM格式
//        outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger; // 整形
//        outputFormat.mFramesPerPacket  = 1; // 每帧只有1个packet
//        outputFormat.mChannelsPerFrame = 2; // 声道数
//        outputFormat.mBytesPerFrame    = 2; // 每帧只有2个byte 声道*位深*Packet数
//        outputFormat.mBytesPerPacket   = 2; // 每个Packet只有2个byte
//        outputFormat.mBitsPerChannel   = 16; // 位深
        
//        AKSettings.defaultAudioFormat.commonFormat = AVAudioCommonFormat.pcmFormatFloat32
//            [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:44100 channels:2 interleaved:YES];
        AKSettings.audioInputEnabled = false
        AKSettings.channelCount = 2
        AKSettings.sampleRate = 44100
        
//        mic = AKMicrophone()
        pcmreader = AKPCMReaderNode();
        tracker = AKFrequencyTracker(pcmreader)
//        silence = AKBooster(tracker, gain: 0.5)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        AKManager.output = tracker
        
        do {
            try AKManager.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
        setupPlot()
        Timer.scheduledTimer(timeInterval: 0.1,
                             target: self,
                             selector: #selector(ViewController.updateUI),
                             userInfo: nil,
                             repeats: true)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @objc func updateUI() {
        if tracker.amplitude > 0.1 {
            let trackerFrequency = Float(tracker.frequency)

            guard trackerFrequency < 7_000 else {
                // This is a bit of hack because of modern Macbooks giving super high frequencies
                return
            }

            frequencyLabel.stringValue = String(format: "%0.1f", tracker.frequency)

            var frequency = trackerFrequency
            while frequency > Float(noteFrequencies[noteFrequencies.count - 1]) {
                frequency /= 2.0
            }
            while frequency < Float(noteFrequencies[0]) {
                frequency *= 2.0
            }

            var minDistance: Float = 10_000.0
            var index = 0

            for i in 0..<noteFrequencies.count {
                let distance = fabsf(Float(noteFrequencies[i]) - frequency)
                if distance < minDistance {
                    index = i
                    minDistance = distance
                }
            }
            let octave = Int(log2f(trackerFrequency / frequency))
            noteNameWithSharpsLabel.stringValue = "\(noteNamesWithSharps[index])\(octave)"
            noteNameWithFlatsLabel.stringValue = "\(noteNamesWithFlats[index])\(octave)"
        }
        amplitudeLabel.stringValue = String(format: "%0.2f", tracker.amplitude)
    }
}
