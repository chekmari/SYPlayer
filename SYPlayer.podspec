Pod::Spec.new do |s|
s.name             = "smartyard-player"
s.version          = "1.0.0"
s.summary          = "Video Player Using Swift, based on AVPlayer"
s.swift_versions   = "5"
s.description      = <<-DESC
Video Player Using Swift, based on AVPlayer, support for the horizontal screen, vertical screen, the upper and lower slide to adjust the volume, the screen brightness, or so slide to adjust the playback progress.
DESC

s.homepage         = "https://github.com/chekmari/SYPlayer"

s.license          = 'MIT'
s.author           = { "Aleksandr Popov" => "stirinmore@gmail.com" }
s.source           = { :git => "https://github.com/chekmari/SYPlayer", :tag => s.version.to_s }

s.ios.deployment_target = '12.0'
s.platform     = :ios, '12.0'
s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
s.default_subspec = 'Full'

s.subspec 'Core' do |core|
    core.frameworks   = 'UIKit', 'AVFoundation'
    core.source_files = 'Source/SYPlayerLayerView.swift'
end

s.subspec 'Full' do |full|
    full.source_files = 'Source/*.swift','Source/Default/*'
    full.resources    = "Source/**/*.xcassets"
    full.frameworks   = 'UIKit', 'AVFoundation'

    full.dependency 'SYPlayer/Core'
    full.dependency 'SnapKit',
    full.dependency 'Lottie',
end

s.subspec 'CacheSupport' do |cache|
    cache.source_files = 'Source/*.swift','Source/CacheSupport/*'
    cache.resources    = "Source/**/*.xcassets"
    cache.frameworks   = 'UIKit', 'AVFoundation'

    cache.dependency 'SYPlayer/Core'
    cache.dependency 'SnapKit',
    cache.dependency 'Lottie',
    cache.dependency 'VIMediaCache'
end

end
