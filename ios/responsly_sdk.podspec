#
# The CocoaPods build of the plugin. Swift Package Manager uses responsly_sdk/Package.swift;
# both build the same sources: the plugin class and the Responsly iOS SDK in
# responsly_sdk/Sources/responsly_sdk/ResponslySDK (copied by tool/sync_native.sh).
#
require 'yaml'

pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))

Pod::Spec.new do |s|
  s.name             = 'responsly_sdk'
  s.version          = pubspec['version'].split('+').first
  s.summary          = 'Show Responsly surveys inside Flutter apps.'
  s.description      = <<-DESC
The Responsly SDK shows in-app surveys as a bottom sheet, a dialog or full screen.
Targeting (events, screens, user traits, sampling, frequency) runs on the device.
                       DESC
  s.homepage         = 'https://developers.responsly.com/mobile-sdk/'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'Responsly'
  s.source           = { :path => '.' }
  s.source_files     = 'responsly_sdk/Sources/responsly_sdk/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'UIKit', 'WebKit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # The privacy manifest of the native SDK (UserDefaults access, no tracking).
  s.resource_bundles = {
    'responsly_sdk_privacy' => ['responsly_sdk/Sources/responsly_sdk/ResponslySDK/Resources/PrivacyInfo.xcprivacy']
  }
end
