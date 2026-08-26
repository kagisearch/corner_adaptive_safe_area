#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint corner_adaptive_safe_area.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'corner_adaptive_safe_area'
  s.version          = '0.0.2'
  s.summary          = 'Bridges iPadOS 26 corner adaptation margins to Flutter.'
  s.description      = <<-DESC
Exposes UIView corner-adaptation layout region insets (iPadOS 26+) to Flutter so
widgets can avoid floating-window controls and rounded display corners on iPad.
                       DESC
  s.homepage         = 'https://kagi.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Kagi' => 'support@kagi.com' }
  s.source           = { :path => '.' }
  s.source_files = 'corner_adaptive_safe_area/Sources/corner_adaptive_safe_area/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.10'

  s.resource_bundles = {
    'corner_adaptive_safe_area_privacy' => [
      'corner_adaptive_safe_area/Sources/corner_adaptive_safe_area/PrivacyInfo.xcprivacy'
    ]
  }
end
