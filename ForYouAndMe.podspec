#
# Be sure to run `pod lib lint ForYouAndMe.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ForYouAndMe'
  s.version          = '0.95.4'
  s.summary          = 'Framework for research studies apps'
  s.description      = <<-DESC
                       ForYouAndMe is a framework aimed to easily develop an app for research study
  DESC

  s.homepage         = 'https://github.com/4YouandMeData/4YouandMeiOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Giuseppe Lapenta' => 'giuseppe@balzo.eu' }
  s.source           = { :git => 'https://github.com/4YouandMeData/4YouandMeiOS.git', :tag => s.version.to_s }

  s.cocoapods_version = '>= 1.6.0'
  
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  
  s.ios.deployment_target = '15.6'
  
  s.swift_version = "5.2"

  s.source_files = 'ForYouAndMe/Classes/**/*'
  
  s.resource_bundles = {
      'ForYouAndMe' => ['ForYouAndMe/Assets/**/*.{json,xcassets}']
  }
  
  s.vendored_frameworks = 'ForYouAndMe/Frameworks/MirSmartDevice.framework'

  s.pod_target_xcconfig = {
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64 arm64'
  }

  s.xcconfig = {
      'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/ForYouAndMe/Frameworks/**'
  }
   
  s.frameworks = 'UIKit'
  
  s.dependency 'Moya/RxSwift', '~> 15.0.0'
  s.dependency 'Moya/ReactiveSwift', '~> 15.0.0'
  s.dependency 'AlamofireImage', '~> 4.3.0'
  s.dependency 'RxCocoa', '~> 6.0'
  s.dependency 'PureLayout', '~> 3.1.9'
  s.dependency 'SVProgressHUD', '~> 2.3.1'
  s.dependency 'TPKeyboardAvoiding', '~> 1.3.3'
  s.dependency 'OAuthSwift', '~> 2.1.2'
  s.dependency 'ReachabilitySwift', '~> 5.2.4'
  s.dependency 'Validator', '~> 3.2.1'
  s.dependency 'Firebase/Analytics', '~> 11.7.0'
  s.dependency 'Firebase/Crashlytics', '~> 11.7.0'
  s.dependency 'Firebase/Messaging', '~> 11.7.0'
  s.dependency 'PhoneNumberKit', '3.3.1'
  s.dependency 'CountryPickerView', '~> 3.1.2'
  s.dependency 'UberSignature', '~> 1.0.3'
  s.dependency 'RxSwiftExt', '~> 6.2.1'
  s.dependency 'FYAMResearchKit', '~> 3.0.0'
  s.dependency 'StepSlider', '~> 1.8.0'
  s.dependency 'BalzoGPUImage2', '~> 0.2.1'
  s.dependency 'JJFloatingActionButton', '~> 3.0.1'

  
  s.static_framework = true
  
end
