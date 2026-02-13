# NB keep in sync with Package.swift
Pod::Spec.new do |s|
  s.name             = 'LightstreamerClient'
  s.version          = '6.4.0-alpha.1'
  s.summary          = 'Lightstreamer Swift Client SDK'
  s.homepage         = 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Lightstreamer' => 'support@lightstreamer.com' }
  s.source           = { :git => 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git', :tag => s.version.to_s }
  #s.source           = { :git => 'https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git', :branch => 'cocoapds' }
  s.ios.deployment_target = '13.0'
  s.macos.deployment_target = '10.15'
  s.watchos.deployment_target = '6.0'
  s.tvos.deployment_target = '13.0'
  s.swift_version = '5.1'
  # Source files to be compiled.
  # They belong to the `LightstreamerClient` library, defined in the `products` element of the `Package.swift` file.
  s.source_files = 'Sources/LightstreamerClient/**/*'
  # Xcode compiler settings (this goes into the `.xcconfig` file used by the pod target, e.g. `LightstreamerClient-library.debug.xcconfig`)
  s.pod_target_xcconfig = {
    # These settings correspond to the `swiftSettings` element in the `Package.swift` file.
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LS_JSON_PATCH'
  }
  
  s.dependency 'RMJSONPatch', '~> 1.0.5' # upToNextMajor
end
