//
//  SmartYardPlayerControlView.swift
//  SmartYard
//
//  Created by Александр Попов on 01.07.2024.
//  Copyright © 2024 LanTa. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import Lottie
import Kingfisher

extension SYPlayerControlView {
    enum ButtonType: Int {
        case play              = 101
        case pause             = 102
        case favourite         = 103
        case close             = 104
    }
}

// MARK: - protocol SYPlayerControlViewDelegate
protocol SYPlayerControlViewDelegate: AnyObject {
    
    /// call when needs to change playback rate
    func controlView(controlView: SYPlayerControlView, didChangeVideoPlaybackRate rate: Float)

    /// call when control view pressed an button
    func controlView(controlView: SYPlayerControlView, didPressButton button: UIButton)
}

// swiftlint:disable:next type_body_length
class SYPlayerControlView: UIView {
    
    weak var delegate: SYPlayerControlViewDelegate?
    // weak var player: SYPlayer?
    // MARK: - Variables
    var resource: SYPlayerResource?
    
    var delayItem: DispatchWorkItem?
    
    var selectedIndex = 0
    var isShowing = false
    var hasSound = true // представим что будет true
    
    var totalDuration: TimeInterval = 0
    
    var playerLastState: SYPlayerState = .notSetURL
    
    // MARK: - UI Elements
    var mainMaskView = UIView()
    var mainView     = UIView()
    var topView      = UIView()
    var bottomView   = UIView()
    
    /// image view
    var imageView = UIImageView()
    
    /// Top view elements
    var titleLabel = UILabel()
    var closeButton = UIButton(type: .custom)
    var soundToggleButton = UIButton(type: .custom)
    
    /// Center view elements
    var videoLoadingAnimationView = LottieAnimationView()
    
    /// Arсhive view elements
    var previousSpeedButton = UIButton(type: .custom)
    var nextSpeedButton = UIButton(type: .custom)
    var playButton = UIButton(type: .custom)
    var periodCollectionView: UICollectionView!
    var progressSlider = SimpleVideoRangeSlider()
    
    /// Bottom view elements
    var liveLabel = UILabel()
    
    /// Gestures
    var tapGesture: UITapGestureRecognizer!
    
    /// RxSwift
    let isSoundOn = BehaviorSubject<Bool>(value: false)
    let isPortrait = BehaviorSubject<Bool>(value: true)
    let isControlViewShowing = BehaviorSubject<Bool>(value: false)
    let playerStateSubject = BehaviorSubject<SYPlayerState>(value: .notSetURL)
    
    let disposeBag = DisposeBag()
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        addLayoutContstraints()
        bind()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI update related function
    func prepareUI(for resource: SYPlayerResource, selectedIndex index: Int) {
        self.resource = resource
        self.selectedIndex = index
        self.titleLabel.text = resource.name
        autoFadeOutControlViewWithAnimation()
    }

    // MARK: - Bind
    func bind() {
        /// Buttons
        closeButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                /// Some functions
                self?.onButtonTapped(self!.closeButton)
            })
            .disposed(by: disposeBag)
        
        /// Подписка на изменения ориентации экрана
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .map { _ in UIDevice.current.orientation }
            .subscribe(onNext: { [weak self] orientation in
                self?.handleOrientationChange(orientation)
            })
            .disposed(by: disposeBag)
        
        /// Подписка на состояния плеера
        playerStateSubject
            .subscribe(onNext: { [weak self] state in
                guard let self = self else { return }
                playerLastState = state
                
                switch state {
                case .notSetURL:
                    showLoader()
                    isControlViewShowing(element: true)
                case .readyToPlay:
                    self.hideLoader()
                case .buffering:
                    self.showLoader()
                case .bufferFinished:
                    self.hideLoader()
                case .playedToTheEnd:
                    //   self.playButton.isSelected = false
                    isControlViewShowing(element: true)
                    
                default:
                    break
                }
                
            })
            .disposed(by: disposeBag)
        
        /// Подписка на состояние отображения view controls
        isControlViewShowing
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] isShowing in
                guard let self = self else { return }
                // скрываем/ показываем пользователю view control
                let alpha: CGFloat = isShowing ? 1.0 : 0.0
                self.isShowing = isShowing
                
                UIApplication.shared.setStatusBarHidden(!isShowing, with: .fade)
                
                UIView.animate(withDuration: 0.3, animations: { [weak self] in
                    guard let self = self else { return }
                    self.topView.alpha = alpha
                    self.bottomView.alpha = alpha
                    self.mainView.alpha = alpha
                    self.mainMaskView.backgroundColor = 
                        .black
                        .withAlphaComponent(isShowing ? 0.4 : 0.0)
                    self.layoutIfNeeded()
                }) { [weak self] (_) in
                    if isShowing {
                        self?.autoFadeOutControlViewWithAnimation()
                    }
                }
                
            })
            .disposed(by: disposeBag)
        
        /// Подписка на вкл/выкл звука 
        isSoundOn
            .asDriver(onErrorJustReturn: false)
            .drive(
                onNext: { [weak self] isSoundOn in
                    self?.soundToggleButton.isSelected = isSoundOn
                }
            )
            .disposed(by: disposeBag)
    }
    
    // MARK: - Player state functions
    open func showLoader() {
        videoLoadingAnimationView.isHidden = false
        videoLoadingAnimationView.play()
    }
    
    func hideLoader() {
        videoLoadingAnimationView.isHidden = true
        videoLoadingAnimationView.stop()
    }
    
    func showImageViewWithLink(_ string: String) {
        self.showImageView(url: URL(string: string))
    }
    
    func showImageView(url: URL?) {
        guard let url = url else {
            imageView.image = nil
            hideLoader()
            return
        }
        
        imageView.kf.setImage(with: url, completionHandler: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let value):
                self.imageView.image = value.image
            case .failure:
                self.imageView.image = nil
            }
            self.hideLoader()
        })
    }
    
    func hideImageView() {
        self.imageView.isHidden = true
    }
    
    func playerStateDidChange(state: SYPlayerState) {
        playerStateSubject.onNext(state)
    }
    
    func isControlViewShowing(element: Bool) {
        isControlViewShowing.onNext(element)
    }
    
    func playStateDidChange(isPlaying: Bool) {
        autoFadeOutControlViewWithAnimation()
        playButton.isSelected = isPlaying
    }
    
    func autoFadeOutControlViewWithAnimation() {
        cancelAutoFadeOutAnimation()
        delayItem = DispatchWorkItem { [weak self] in
            if self?.playerLastState == .playedToTheEnd {
                self?.isControlViewShowing(element: false)
            }
        }
        
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + SYPlayerConfig.shared.animateTimeInterval,
            execute: delayItem!
        )
    }
    
    func cancelAutoFadeOutAnimation() {
        delayItem?.cancel()
    }
    
    func prepareToDealloc() {
        delayItem = nil
    }
    
    // MARK: - UI customize
    func setupUI() {
        mainMaskView.backgroundColor = .black.withAlphaComponent(0.4)
        
        /// Main view setup
        mainView.clipsToBounds = true
        
        /// Top view setup
        titleLabel.text = "Камера Беварда подъезд 1"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.SourceSansPro.semibold(size: 24)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        
        closeButton.imageForNormal = UIImage(resource: .minimize)
        closeButton.tintColor = .white
        closeButton.tag = SYPlayerControlView.ButtonType.close.rawValue
        closeButton.touchAreaInsets = UIEdgeInsets(inset: 12)
        
        soundToggleButton.imageForNormal = UIImage(resource: .soundOff)
        soundToggleButton.imageForSelected = UIImage(resource: .soundOn)
        soundToggleButton.touchAreaInsets = UIEdgeInsets(inset: 12)
        soundToggleButton.isHidden = !hasSound
        soundToggleButton.rx.tap
            .withLatestFrom(isSoundOn) { _, isSoundOn in !isSoundOn }
            .bind(to: isSoundOn)
            .disposed(by: disposeBag)
          
        /// Center view setup
        let animation = LottieAnimation.named("LoaderAnimation")
        
        videoLoadingAnimationView.animation = animation
        videoLoadingAnimationView.loopMode = .loop
        videoLoadingAnimationView.backgroundBehavior = .pauseAndRestore
        
        /// Bottom view setup
        
        /// Gestures
        tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(onTapGestureTapped(_:))
        )
        addGestureRecognizer(tapGesture)
        
        /// Archive views
        guard SYPlayerConfig.shared.videoType == .archive else {
            return
        }
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        periodCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        periodCollectionView.touchAreaInsets = UIEdgeInsets(inset: 8)
        periodCollectionView.isPrefetchingEnabled = true
        periodCollectionView.backgroundColor = .clear
        periodCollectionView.showsHorizontalScrollIndicator = false
        periodCollectionView.showsVerticalScrollIndicator = false
        periodCollectionView.contentMode = .scaleToFill
        periodCollectionView.delegate = self
        periodCollectionView.dataSource = self
        periodCollectionView.register(nibWithCellClass: VideoPeriodPickerCell.self)
        
        progressSlider.setReferenceCalendar(.serverCalendar)
        progressSlider.touchAreaInsets = UIEdgeInsets(inset: 6)
        progressSlider.delegate = self
        
        playButton.imageForNormal   = UIImage(resource: .play)
        playButton.imageForSelected = UIImage(resource: .pause)
        playButton.touchAreaInsets = UIEdgeInsets(inset: 6)
        
        previousSpeedButton.titleForNormal = "0.5x"
        previousSpeedButton.setTitleColorForAllStates(.white)
        previousSpeedButton.touchAreaInsets = UIEdgeInsets(inset: 12)
        previousSpeedButton.titleLabel?.font = UIFont.SourceSansPro.regular(size: 20)
        
        nextSpeedButton.titleForNormal = "1.5x"
        nextSpeedButton.setTitleColorForAllStates(.white)
        nextSpeedButton.touchAreaInsets = UIEdgeInsets(inset: 12)
        nextSpeedButton.titleLabel?.font = UIFont.SourceSansPro.regular(size: 20)
    }
    
    func addLayoutContstraints() {
        addSubview(mainMaskView)
        mainMaskView.addSubview(mainView)
        mainMaskView.addSubview(videoLoadingAnimationView)
        
        mainView.addSubview(topView)
        mainView.addSubview(bottomView)
        mainView.insertSubview(imageView, at: 0)
        
        topView.addSubview(closeButton)
        topView.addSubview(soundToggleButton)
        topView.addSubview(titleLabel)
        
        mainMaskView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        /// Main view setup
        mainView.snp.makeConstraints {
            $0.edges.equalTo(safeAreaLayoutGuide)
        }
        imageView.snp.makeConstraints {
            $0.edges.equalTo(mainView)
        }
        topView.snp.makeConstraints {
            $0.left.right.equalToSuperview()
            $0.height.equalTo(44)
        }
        
        /// Top view setup
        closeButton.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().dividedBy(2)
            $0.centerY.equalToSuperview()
            $0.right.equalToSuperview().inset(16)
            $0.width.equalTo(32)
        }
        
        soundToggleButton.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().dividedBy(2)
            $0.centerY.equalToSuperview()
            $0.left.equalToSuperview().inset(16)
            $0.width.equalTo(32)
        }
            
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(topView.snp.bottom).offset(26)
            $0.left.right.equalToSuperview().inset(26)
            $0.height.equalTo(44)
        }
        
        /// Center view setup
        videoLoadingAnimationView.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.height.width.equalTo(80)
        }
        
        /// Bottom view setup
        guard SYPlayerConfig.shared.videoType == .archive else {
            
            bottomView.snp.makeConstraints {
                $0.bottom.left.right.equalToSuperview()
                $0.height.equalTo(44)
            }
            
            return
        }
        
        bottomView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(8)
            $0.left.right.equalToSuperview()
            $0.top.equalTo(videoLoadingAnimationView.snp.bottom).offset(24)
        }
        
        let buttonsCentering = UIView()
        bottomView.addSubview(buttonsCentering)
        bottomView.addSubview(periodCollectionView)
        bottomView.addSubview(progressSlider)
        buttonsCentering.addSubview(playButton)
        buttonsCentering.addSubview(previousSpeedButton)
        buttonsCentering.addSubview(nextSpeedButton)
        
        buttonsCentering.snp.makeConstraints {
            $0.height.equalTo(68)
            $0.left.right.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview()
        }
        
        playButton.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.height.width.equalTo(68)
            $0.left.greaterThanOrEqualTo(previousSpeedButton.snp.right).offset(20)
        }
        
        previousSpeedButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.left.equalToSuperview().inset(20)
        }
        
        nextSpeedButton.snp.makeConstraints {
            $0.right.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
            $0.left.greaterThanOrEqualTo(playButton.snp.right).offset(20)
        }
                
        periodCollectionView.snp.makeConstraints {
            $0.left.right.equalToSuperview()
            $0.bottom.equalTo(buttonsCentering.snp.top).offset(-16)
            $0.height.equalTo(24)
        }
        
        progressSlider.snp.makeConstraints {
            $0.height.equalTo(37)
            $0.bottom.equalTo(periodCollectionView.snp.top).offset(-16)
            $0.left.right.equalToSuperview().inset(12)
        }
    }
    
    func updateUI(isPortrait: Bool) {
        titleLabel.snp.remakeConstraints {
            if isPortrait {
                $0.top.equalTo(topView.snp.bottom).offset(26)
                $0.left.right.equalToSuperview().inset(26)
            } else {
                $0.left.equalTo(soundToggleButton.snp.right)
                $0.right.equalTo(closeButton.snp.left)
            }
            $0.height.greaterThanOrEqualTo(44)
        }
        layoutIfNeeded()
        
        guard SYPlayerConfig.shared.videoType == .archive else { return }
        
        bottomView.snp.remakeConstraints {
            
            if isPortrait {
                $0.bottom.equalToSuperview()
                $0.left.right.equalToSuperview()
                $0.top.equalTo(videoLoadingAnimationView.snp.bottom).offset(24)
            } else {
                $0.bottom.equalToSuperview().inset(4)
                $0.left.right.equalToSuperview()
                $0.top.equalTo(videoLoadingAnimationView)
            }
        }
        
        layoutIfNeeded()
    }
    
    // MARK: - Actions Response
    private func onButtonTapped(_ button: UIButton) {
        guard let type = ButtonType(rawValue: button.tag) else {
            return
        }
        
        switch type {
        case .play:
            print("play")
        case .pause:
            print("pause")
        case .close:
            print("close")
        case .favourite:
            print("favourite")
        }
        
        delegate?.controlView(controlView: self, didPressButton: button)
    }
    
    @objc
    private func onTapGestureTapped(_: UIGestureRecognizer) {
        if playerLastState == .playedToTheEnd {
            return
        }
        
        isControlViewShowing(element: !isShowing)
    }
}

extension SYPlayerControlView {
    private func handleOrientationChange(_ orientation: UIDeviceOrientation) {
        switch orientation {
        case .portrait:
            updateUI(isPortrait: true)
        case .landscapeLeft:
            updateUI(isPortrait: false)
        default:
            break
        }
    }
}

extension SYPlayerControlView: UICollectionViewDelegate, UICollectionViewDataSource{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       4
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: VideoPeriodPickerCell.self, for: indexPath)
        
        cell.setTitle("period.title")

        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension SYPlayerControlView: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return CGSize(width: 96, height: 24)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 18
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 18
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }
}

// MARK: - SimpleVideoRangeSliderDelegate
extension SYPlayerControlView: SimpleVideoRangeSliderDelegate {
    func didChangeDate(videoRangeSlider: SimpleVideoRangeSlider, isReceivingGesture: Bool, startDate: Date, endDate: Date, isLowerBoundReached: Bool, isUpperBoundReached: Bool, screenshotPolicy: SimpleVideoRangeSlider.ScreenshotPolicy) {
        
    }
}
