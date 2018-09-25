Pod::Spec.new do |s|
  s.name             = 'LLVideoPlayer'
  s.version          = '0.9.11'
  s.summary          = 'A low level, flexible video player based on AVPlayer for iOS.'

  s.description      = <<-DESC
LLVideoPlayer is a low level video player which is simple and easy to extend.
                       DESC

  s.homepage         = 'https://github.com/huangguiyang/LLVideoPlayer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'mario' => 'mohu3g@163.com' }
  s.source           = { :git => 'https://github.com/huangguiyang/LLVideoPlayer.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.public_header_files = 'LLVideoPlayer/*.h'
  s.source_files = 'LLVideoPlayer/*.{m,h}'

  s.subspec 'CacheSupport' do |ss|
	ss.source_files = 'LLVideoPlayer/CacheSupport'
  end

  s.frameworks = 'QuartzCore', 'MediaPlayer', 'AVFoundation'
end
