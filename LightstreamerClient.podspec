# NB keep in sync with Package.swift
Pod::Spec.new do |s|
  s.name             = 'LightstreamerClient'
  s.version          = '6.1.0'
  s.summary          = 'Lightstreamer Swift Client SDK'
  s.homepage         = 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE.md' }
  s.author           = { 'Lightstreamer' => 'support@lightstreamer.com' }
  s.source           = { :git => 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git', :tag => s.version.to_s }
  #s.source           = { :git => 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git', :branch => 'cocoapds' }
  s.ios.deployment_target = '11.0'
  s.macos.deployment_target = '10.13'
  s.watchos.deployment_target = '5.0'
  s.tvos.deployment_target = '12.0'
  s.swift_version = '5.1'
  s.source_files = 'Sources/LightstreamerClient/**/*'
  
  s.dependency 'Starscream', '~> 4.0.6' # upToNextMajor
  s.dependency 'Alamofire', '~> 5.8.1' # upToNextMajor
  s.dependency 'RMJSONPatch', '~> 1.0.4' # upToNextMajor
end
