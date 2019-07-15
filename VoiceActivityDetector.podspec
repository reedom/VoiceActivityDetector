#
# Be sure to run `pod lib lint VoiceActivityDetector.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'VoiceActivityDetector'
  s.version          = '0.2.0'
  s.summary          = 'WebRTC based voice activity detection.'
  s.homepage         = 'https://github.com/reedom/VoiceActivityDetector'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'reedom' => 'tohru@reedom.com' }
  s.source           = { :git => 'https://github.com/reedom/VoiceActivityDetector.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.swift_version = "5.0"
  s.source_files = 'VoiceActivityDetector/Classes/**/*'
  s.dependency 'libfvad', '~> 0.1.0'
end
