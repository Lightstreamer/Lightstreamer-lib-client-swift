Pod::Spec.new do |s|
  s.name             = 'LightstreamerClient'
  s.version          = '5.0.0-beta.3'
  s.summary          = 'Lightstreamer Swift Client SDK'
  s.homepage         = 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE.md' }
  s.author           = { 'Lightstreamer' => 'support@lightstreamer.com' }
  s.source           = { :git => 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git', :tag => s.version.to_s }
  s.ios.deployment_target = '10.0'
  s.macos.deployment_target = '10.12'
  s.watchos.deployment_target = '3.0'
  s.tvos.deployment_target = '10.0'
  s.swift_version = '5.1'
  s.source_files = 'Sources/LightstreamerClient/**/*'
  
  s.dependency 'Starscream', '~> 4.0' # upToNextMajor
  s.dependency 'Alamofire', '~> 5.2' # upToNextMajor
end
