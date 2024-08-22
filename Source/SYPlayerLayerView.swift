//
//  SYPlayerLayerView.swift
//  SmartYard
//
//  Created by Александр Попов on 08.08.2024.
//  Copyright © 2024 LanTa. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

protocol SYPlayerLayerViewDelegate: AnyObject {
    func syPlayer(layerView: SYPlayerLayerView, playerStateDidChange state: SYPlayerState)
    func syPlayer(layerView: SYPlayerLayerView, loadedTimeDidChange loadedDuration: TimeInterval, totalDuration: TimeInterval)
    func syPlayer(layerView: SYPlayerLayerView, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval)
    func syPlayer(layerView: SYPlayerLayerView, playerIsPlaying playing: Bool)
}

// swiftlint:disable type_body_length
class SYPlayerLayerView: UIView {
    weak var delegate: SYPlayerLayerViewDelegate?
    
    var seekTime = 0
    
    var playerItem: AVPlayerItem? {
        didSet {
            self.onPlayerItemChange()
        }
    }
    
    lazy var player: AVPlayer? = {
        if let item = self.playerItem {
            let player = AVPlayer(playerItem: item)
            return player
        }
        return nil
    }()
    
    var videoGravity = AVLayerVideoGravity.resizeAspect {
        didSet {
            self.playerLayer?.videoGravity = videoGravity
        }
    }
    
    var isPlaying = false {
        didSet {
            if oldValue != isPlaying {
                delegate?.syPlayer(layerView: self, playerIsPlaying: isPlaying)
            }
        }
    }
    
    var aspectRatio: SYPlayerAspectRatio = .default {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    var timer: Timer?
    
    fileprivate var playerLayer: AVPlayerLayer?
    fileprivate var lastPlayerItem: AVPlayerItem?
    fileprivate var urlAsset: AVURLAsset?
    fileprivate var state = SYPlayerState.notSetURL {
        didSet {
            if state != oldValue {
                delegate?.syPlayer(layerView: self, playerStateDidChange: state)
            }
        }
    }
    fileprivate var playDidEnd     = false
    fileprivate var repeatToPlay   = false
    fileprivate var isBuffering    = false
    fileprivate var hasReadyToPlay = false
    fileprivate var shouldSeekTo: TimeInterval = 0
    
    // MARK: - Actions
    
    func play(url: URL) {
        let asset = AVURLAsset(url: url)
        playAsset(asset: asset)
    }
    
    func playAsset(asset: AVURLAsset) {
        self.urlAsset = asset
        onSetVideoAsset()
        play()
    }
    
    func play() {
        guard let player = self.player else { return }
        
        player.play()
        setupTimer()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        timer?.fireDate = Date.distantFuture
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        switch self.aspectRatio {
        case .default:
            playerLayer?.videoGravity = .resizeAspect
            playerLayer?.frame = self.bounds
            
        case .sixteen2nine:
            playerLayer?.videoGravity = .resize
            playerLayer?.frame = CGRect(x: 0,
                                        y: 0,
                                        width: self.bounds.width,
                                        height: self.bounds.width / (16 / 9))
            
        case .four2three:
            playerLayer?.videoGravity = .resize
            let width = self.bounds.height * 4 / 3
            playerLayer?.frame = CGRect(x: (self.bounds.width - width) / 2,
                                        y: 0,
                                        width: width,
                                        height: self.bounds.height)
        }
    }
    
    func resetPlayer() {
        /// Init
        
        playDidEnd = false
        playerItem = nil
        lastPlayerItem = nil
        seekTime = 0
        
        timer?.invalidate()
        
        pause()
        
        playerLayer?.removeFromSuperlayer()
        
        player?.replaceCurrentItem(with: nil)
        
        player?.removeObserver(self, forKeyPath: "rate")
        
        player = nil
    }
    
    func prepareToDeinit() {
        resetPlayer()
    }
    
    func seek(to seconds: TimeInterval, completion: (() -> Void)?) {
        if seconds.isNaN { return }
        
        setupTimer()
        
        if player?.currentItem?.status == AVPlayerItem.Status.readyToPlay {
            let draggedTime = CMTime(value: Int64(seconds), timescale: 1)
            player!.seek(to: draggedTime,
                        toleranceBefore: CMTime.zero,
                        toleranceAfter: CMTime.zero,
                        completionHandler: { finished in
                completion?()
            })
        } else {
            shouldSeekTo = seconds
        }
    }
    
    // MARK: - Set URL video
    
    fileprivate func onSetVideoAsset() {
        repeatToPlay = false
        playDidEnd   = false
        configurePlayer()
    }
    
    fileprivate func onPlayerItemChange() {
        if lastPlayerItem == playerItem {
            return
        }
        
        if let item = lastPlayerItem {
            
            NotificationCenter
                .default
                .removeObserver(self,
                                name: AVPlayerItem.didPlayToEndTimeNotification,
                                object: item)
            item.removeObserver(self, forKeyPath: "status")
            item.removeObserver(self, forKeyPath: "loadedTimeRanges")
            item.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            item.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        }
        
        self.lastPlayerItem = self.playerItem
        
        if let item = self.playerItem {
            NotificationCenter.default
                .addObserver(
                    self,
                    selector: #selector(videoPlayDidEnd),
                    name: AVPlayerItem.didPlayToEndTimeNotification,
                    object: self.playerItem
                )
                
            item.addObserver(self,
                             forKeyPath: "status",
                             context: nil)
            item.addObserver(self,
                             forKeyPath: "loadedTimeRanges",
                             context: nil)
            item.addObserver(self,
                             forKeyPath: "playbackBufferEmpty",
                             context: nil)
        }
    }
    
    fileprivate func configurePlayer() {
        player?.removeObserver(self,
                               forKeyPath: "rate")
        playerItem = AVPlayerItem(asset: urlAsset!)
        player = AVPlayer(playerItem: playerItem!)
        player!.addObserver(self,
                            forKeyPath: "rate",
                            options: NSKeyValueObservingOptions.new,
                            context: nil)
        
        connectPlayerLayer()
        setNeedsLayout()
        layoutIfNeeded()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.connectPlayerLayer),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.disconnectPlayerLayer),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }
    
    func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.5,
                                     target: self,
                                     selector: #selector(playerTimeAction),
                                     userInfo: nil,
                                     repeats: true)
        timer?.fireDate = Date()
    }
    
    // MARK: - Timer Actions
    
    @objc fileprivate func playerTimeAction() {
        guard let playerItem = self.playerItem else { return }
        
        if playerItem.duration.timescale != 0 {
            let currentTime = CMTimeGetSeconds(self.player!.currentTime()) // TODO: - если будет краш, смотреть сюда
            let totalTime   = TimeInterval(playerItem.duration.value) / TimeInterval(playerItem.duration.timescale)
            
            delegate?.syPlayer(layerView: self, 
                               playTimeDidChange: currentTime,
                               totalTime: totalTime)
        }
        
        updateStatus(includeLoading: true)
    }
    
    fileprivate func updateStatus(includeLoading: Bool = false) {
        guard let player = self.player else { return }
        
        // Если playerItem существует и необходимо учитывать загрузку (includeLoading == true).
        if let playerItem = self.playerItem , includeLoading {
            
            // Проверяем, сможет ли player продолжить воспроизведение без буферизации или если буфер заполнен.
            // Обновляем состояние на "буферизация завершена".
            // Если статус проигрываемого элемента - ошибка, обновляем состояние на "ошибка".
            // В противном случае обновляем состояние на "буферизация"
            if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
                state = .bufferFinished
            } else if playerItem.status == .failed {
                state = .error
            } else {
                state = .buffering
            }
            
            if player.rate == 0.0 {
                if player.error != nil {
                    state = .error
                    return
                }
                // Проверяем, есть ли ошибка у проигрывателя. Если да, обновляем состояние на "ошибка" и выходим из метода.
                if let error = player.error {
                    state = .error
                    return
                }

                // Проверяем, есть ли текущий элемент (currentItem) у проигрывателя.
                guard let currentItem = player.currentItem else { return }

                // Если текущее время воспроизведения больше или равно длительности видео.
                if player.currentTime() >= currentItem.duration {
                    videoPlayDidEnd()  // Завершаем воспроизведение, вызывая метод окончания видео.
                    return
                }

                // Если проигрываемый элемент готов к продолжению воспроизведения без буферизации или буфер заполнен.
                if currentItem.isPlaybackLikelyToKeepUp || currentItem.isPlaybackBufferFull {
                    state = .bufferFinished
                }
            }
        }
    }
    
    // MARK: - Notification Event
    
    @objc fileprivate func videoPlayDidEnd() {
        if state != .playedToTheEnd {
            if let playerItem = playerItem {
                delegate?.syPlayer(layerView: self,
                                   playTimeDidChange: CMTimeGetSeconds(playerItem.duration),
                                   totalTime: CMTimeGetSeconds(playerItem.duration))
            }
            
            state = .playedToTheEnd
            isPlaying = false
            playDidEnd = true
            timer?.invalidate()
        }
    }
    
    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if let item = object as? AVPlayerItem,
           let keyPath = keyPath {
            
            if item == self.playerItem {
                switch keyPath {
                case "status":
                    ///
                    if item.status == .failed ||
                        player?.status == .failed { state = .error } else {
                            
                            state = .buffering
                            if shouldSeekTo != 0 {
                                print("SYPlayerLayerView | Should seek to \(shouldSeekTo)")
                                
                                shouldSeekTo = 0
                            }
                        }
                    
                    if item.status == .failed || player?.status == AVPlayer.Status.failed {
                        state = .error
                    } else if player?.status == AVPlayer.Status.readyToPlay {
                       state = .buffering
                        if shouldSeekTo != 0 {
                            print("SYPlayerLayerView | Should seek to \(shouldSeekTo)")
                            seek(to: shouldSeekTo, completion: { [weak self] in
                                self?.shouldSeekTo = 0
                                self?.hasReadyToPlay = true
                                self?.state = .readyToPlay
                            })
                        } else {
                            hasReadyToPlay = true
                            state = .readyToPlay
                        }
                    }
                    
                case "loadedTimeRanges":
                    /// Вычисляем прогресс буферизации
                    if let timeInterval   = self.availableDuration() {
                        let duration      = item.duration
                        let totalDuration = CMTimeGetSeconds(duration)
                        
                        delegate?.syPlayer(layerView: self,
                                           loadedTimeDidChange: timeInterval,
                                           totalDuration: totalDuration)
                    }
                    
                case "playbackBufferEmpty":
                    /// Когда буфер пустой
                    if playerItem!.isPlaybackBufferEmpty {
                        state = .buffering
                        bufferingSomeSecond()
                    }
                    
                case "playbackLikelyToKeepUp":
                    /// Возвращаем прогресс буферизации
                    if item.isPlaybackBufferEmpty {
                        if state != .bufferFinished && hasReadyToPlay {
                            self.state = .bufferFinished
                            self.playDidEnd = true
                        }
                    }
                    
                default:
                    break
                }
            }
            
            if keyPath == "rate" {
                updateStatus()
            }
        }
    }
    
    // Буферизация прогресса
    fileprivate func availableDuration() -> TimeInterval? {
        if let loadedTimeRanges = player?.currentItem?.loadedTimeRanges,
            let first = loadedTimeRanges.first {
            
            let timeRange = first.timeRangeValue
            let startSeconds = CMTimeGetSeconds(timeRange.start)
            let durationSecound = CMTimeGetSeconds(timeRange.duration)
            let result = startSeconds + durationSecound
            return result
        }
        return nil
    }
    
    fileprivate func bufferingSomeSecond() {
        state = .buffering
        
        // playbackBufferEmpty может вызываться несколько раз, поэтому
        // если задержка воспроизведения еще не выполнена, то игнорируем повторные вызовы bufferingSomeSecond
        if isBuffering { return }
        isBuffering = true
        
        // Нужно приостановить воспроизведение на короткое время, а затем возобновить,
        // иначе при плохом интернет-соединении время будет идти, но звук не будет воспроизводиться
        player?.pause()
        
        let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * 1.0 )) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: popTime) {[weak self] in
            guard let self = self else { return }
            
            // Если после выполнения play звук все еще не воспроизводится, значит буферизация не завершена,
            // и нужно подождать еще некоторое время
            self.isBuffering = false
            if let item = self.playerItem {
                if !item.isPlaybackLikelyToKeepUp {
                    self.bufferingSomeSecond()
                } else {
                    // Если пользователь уже нажал паузу, то не нужно снова включать воспроизведение
                    self.state = .bufferFinished
                }
            }
        }
    }
    
    @objc fileprivate func connectPlayerLayer() {
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer!.videoGravity = videoGravity
        
        layer.addSublayer(playerLayer!)
    }
    
    @objc fileprivate func disconnectPlayerLayer() {
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
}
