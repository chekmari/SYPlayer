//
//  VideoPlayViewController.swift
//  SYPlayer
//
//  Created by BrikerMan on 16/4/28.
//  Copyright © 2016年 CocoaPods. All rights reserved.
//

import UIKit
import SYPlayer
import AVFoundation
import NVActivityIndicatorView

func delay(_ seconds: Double, completion:@escaping ()->()) {
  let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)
  
  DispatchQueue.main.asyncAfter(deadline: popTime) {
    completion()
  }
}

class VideoPlayViewController: UIViewController {
  
  //    @IBOutlet weak var player: BMPlayer!
  
  var player: SYPlayer!
  
  var index: IndexPath!
  
  var changeButton = UIButton()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupPlayerManager()
    preparePlayer()
    setupPlayerResource()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(applicationDidEnterBackground),
                                           name: UIApplication.didEnterBackgroundNotification,
                                           object: nil)
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(applicationWillEnterForeground),
                                           name: UIApplication.willEnterForegroundNotification,
                                           object: nil)
  }
  
  @objc func applicationWillEnterForeground() {
    
  }
  
  @objc func applicationDidEnterBackground() {
    player.pause(allowAutoPlay: false)
  }
  
  /**
   prepare playerView
   */
  func preparePlayer() {
    var controller: SYPlayerControlView? = nil
    
    if index.row == 0 && index.section == 2 {
      controller = SYPlayerCustomControlView()
    }
    
    if index.row == 1 && index.section == 2 {
      controller = SYPlayerCustomControlView2()
    }
    
    player = SYPlayer(customControlView: controller)
    view.addSubview(player)
    
    player.snp.makeConstraints { (make) in
      make.top.equalTo(view.snp.top)
      make.left.equalTo(view.snp.left)
      make.right.equalTo(view.snp.right)
      make.height.equalTo(view.snp.width).multipliedBy(9.0/16.0).priority(500)
    }
    
    player.delegate = self
    player.backBlock = { [unowned self] (isFullScreen) in
      if isFullScreen {
        return
      } else {
        let _ = self.navigationController?.popViewController(animated: true)
      }
    }
    
    changeButton.setTitle("Change Video", for: .normal)
    changeButton.addTarget(self, action: #selector(onChangeVideoButtonPressed), for: .touchUpInside)
    changeButton.backgroundColor = UIColor.red.withAlphaComponent(0.7)
    view.addSubview(changeButton)
    
    changeButton.snp.makeConstraints { (make) in
      make.top.equalTo(player.snp.bottom).offset(30)
      make.left.equalTo(view.snp.left).offset(10)
    }
    changeButton.isHidden = true
    self.view.layoutIfNeeded()
  }
  
  
  @objc fileprivate func onChangeVideoButtonPressed() {
    let urls = ["http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4",
                "http://baobab.wdjcdn.com/1456117847747a_x264.mp4",
                "http://baobab.wdjcdn.com/14525705791193.mp4",
                "http://baobab.wdjcdn.com/1456459181808howtoloseweight_x264.mp4",
                "http://baobab.wdjcdn.com/1455968234865481297704.mp4",
                "http://baobab.wdjcdn.com/1455782903700jy.mp4",
                "http://baobab.wdjcdn.com/14564977406580.mp4",
                "http://baobab.wdjcdn.com/1456316686552The.mp4",
                "http://baobab.wdjcdn.com/1456480115661mtl.mp4",
                "http://baobab.wdjcdn.com/1456665467509qingshu.mp4",
                "http://baobab.wdjcdn.com/1455614108256t(2).mp4",
                "http://baobab.wdjcdn.com/1456317490140jiyiyuetai_x264.mp4",
                "http://baobab.wdjcdn.com/1455888619273255747085_x264.mp4",
                "http://baobab.wdjcdn.com/1456734464766B(13).mp4",
                "http://baobab.wdjcdn.com/1456653443902B.mp4",
                "http://baobab.wdjcdn.com/1456231710844S(24).mp4"]
    let random = Int(arc4random_uniform(UInt32(urls.count)))
    let asset = SYPlayerResource(url: URL(string: urls[random])!, name: "Video @\(random)")
    player.setVideo(resource: asset)
  }
  
  
  func setupPlayerResource() {
    switch (index.section,index.row) {
      
    case (0,0):
      let str = Bundle.main.url(forResource: "SubtitleDemo", withExtension: "srt")!
      let url = URL(string: "http://baobab.wdjcdn.com/1456117847747a_x264.mp4")!
      
      let subtitle = BMSubtitles(url: str)
      
      let asset = SYPlayerResource(name: "Video Name Here",
                                   definitions: [SYPlayerResourceDefinition(url: url, definition: "480p")],
                                   cover: nil,
                                   subtitles: subtitle)
      
      // How to change subtiles
      //            delay(5, completion: {
      //                if let resource = self.player.currentResource {
      //                    resource.subtitle = nil
      //                    self.player.forceReloadSubtile()
      //                }
      //            })
      //
      //            delay(10, completion: {
      //                if let resource = self.player.currentResource {
      //                    resource.subtitle = BMSubtitles(url: Bundle.main.url(forResource: "SubtitleDemo2", withExtension: "srt")!)
      //                }
      //            })
      //
      //
      //            // How to change get current uel
      //            delay(5, completion: {
      //                if let resource = self.player.currentResource {
      //                    for i in resource.definitions {
      //                        print("video \(i.definition) url is \(i.url)")
      //                    }
      //                }
      //            })
      //
      player.seek(30)
      player.setVideo(resource: asset)
      changeButton.isHidden = false
      
    case (0,1):
      let asset = self.preparePlayerItem()
      player.setVideo(resource: asset)
      
    case (0,2):
      let asset = self.preparePlayerItem()
      player.setVideo(resource: asset)
      
    case (2,0):
      player.panGesture.isEnabled = false
      let asset = self.preparePlayerItem()
      player.setVideo(resource: asset)
      
    case (2,1):
      player.videoGravity = AVLayerVideoGravity.resizeAspect
      let asset = SYPlayerResource(url: URL(string: "http://baobab.wdjcdn.com/14525705791193.mp4")!, name: "风格互换：原来你我相爱")
      player.setVideo(resource: asset)
      
    default:
      let asset = self.preparePlayerItem()
      player.setVideo(resource: asset)
    }
  }
  
  // 设置播放器单例，修改属性
  func setupPlayerManager() {
    resetPlayerManager()
    switch (index.section,index.row) {
    // 普通播放器
    case (0,0):
      break
    case (0,1):
      break
    case (0,2):
      // 设置播放器属性，此情况下若提供了cover则先展示封面图，否则黑屏。点击播放后开始loading
      SYPlayerConf.shouldAutoPlay = false
      
    case (1,0):
      // 设置播放器属性，此情况下若提供了cover则先展示封面图，否则黑屏。点击播放后开始loading
        SYPlayerConf.topBarShowInCase = .always
      
      
    case (1,1):
        SYPlayerConf.topBarShowInCase = .horizantalOnly
      
      
    case (1,2):
        SYPlayerConf.topBarShowInCase = .none
      
    case (1,3):
        SYPlayerConf.tintColor = UIColor.red
      
    default:
      break
    }
  }
  
  
  /**
   准备播放器资源model
   */
  func preparePlayerItem() -> SYPlayerResource {
    let res0 = SYPlayerResourceDefinition(url: URL(string: "http://baobab.wdjcdn.com/1457162012752491010143.mp4")!,
                                          definition: "高清")
    let res1 = SYPlayerResourceDefinition(url: URL(string: "http://baobab.wdjcdn.com/1457162012752491010143.mp4")!,
                                          definition: "标清")
    
    let asset = SYPlayerResource(name: "周末号外丨中国第一高楼",
                                 definitions: [res0, res1],
                                 cover: URL(string: "http://img.wdjimg.com/image/video/447f973848167ee5e44b67c8d4df9839_0_0.jpeg"))
    return asset
  }
  
  
  func resetPlayerManager() {
      SYPlayerConf.allowLog = false
      SYPlayerConf.shouldAutoPlay = true
      SYPlayerConf.tintColor = UIColor.white
      SYPlayerConf.topBarShowInCase = .always
      SYPlayerConf.loaderType  = NVActivityIndicatorType.ballRotateChase
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.default, animated: false)
    // If use the slide to back, remember to call this method
    // 使用手势返回的时候，调用下面方法
    player.pause(allowAutoPlay: true)
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.lightContent, animated: false)
    // If use the slide to back, remember to call this method
    // 使用手势返回的时候，调用下面方法
    player.autoPlay()
  }
  
  deinit {
    // If use the slide to back, remember to call this method
    // 使用手势返回的时候，调用下面方法手动销毁
    player.prepareToDealloc()
    print("VideoPlayViewController Deinit")
  }
  
}

// MARK:- SYPlayerDelegate example
extension VideoPlayViewController: SYPlayerDelegate {
  // Call when player orinet changed
  func syPlayer(player: SYPlayer, playerOrientChanged isFullscreen: Bool) {
    player.snp.remakeConstraints { (make) in
      make.top.equalTo(view.snp.top)
      make.left.equalTo(view.snp.left)
      make.right.equalTo(view.snp.right)
      if isFullscreen {
        make.bottom.equalTo(view.snp.bottom)
      } else {
        make.height.equalTo(view.snp.width).multipliedBy(9.0/16.0).priority(500)
      }
    }
  }
  
  // Call back when playing state changed, use to detect is playing or not
  func syPlayer(player: SYPlayer, playerIsPlaying playing: Bool) {
    print("| BMPlayerDelegate | playerIsPlaying | playing - \(playing)")
  }
  
  // Call back when playing state changed, use to detect specefic state like buffering, bufferfinished
  func syPlayer(player: SYPlayer, playerStateDidChange state: SYPlayerState) {
    print("| BMPlayerDelegate | playerStateDidChange | state - \(state)")
  }
  
  // Call back when play time change
  func syPlayer(player: SYPlayer, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval) {
    //        print("| BMPlayerDelegate | playTimeDidChange | \(currentTime) of \(totalTime)")
  }
  
  // Call back when the video loaded duration changed
  func syPlayer(player: SYPlayer, loadedTimeDidChange loadedDuration: TimeInterval, totalDuration: TimeInterval) {
    //        print("| BMPlayerDelegate | loadedTimeDidChange | \(loadedDuration) of \(totalDuration)")
  }
}
