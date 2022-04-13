#
# Be sure to run `pod lib lint ForYouAndMe.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ForYouAndMe'
  s.version          = '0.80.0'
  s.summary          = 'Framework for research studies apps'
  s.description      = <<-DESC
                       ForYouAndMe is a framework aimed to easily develop an app for research study
  DESC

  s.homepage         = 'https://github.com/4youandme/4YouandmeiOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'LeonardoPasseri' => 'leonardo@balzo.eu' }
  s.source           = { :git => 'https://github.com/4youandme/4YouandmeiOS.git', :tag => s.version.to_s }

  s.cocoapods_version = '>= 1.6.0'
  
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  
  s.ios.deployment_target = '13.0'
  
  s.swift_version = "5.2"

  s.source_files = 'ForYouAndMe/Classes/**/*'
  
  s.resource_bundles = {
      'ForYouAndMe' => ['ForYouAndMe/Assets/**/*.{json,xcassets}']
  }
   
  s.frameworks = 'UIKit'
  
  s.dependency 'Moya/RxSwift', '~> 14.0.0'
  s.dependency 'Moya-ModelMapper/RxSwift', '~> 10.0.0'
  s.dependency 'AlamofireImage', '~> 4.1'
  s.dependency 'RxCocoa', '~> 5.1.1'
  s.dependency 'PureLayout', '~> 3.1.5'
  s.dependency 'SVProgressHUD', '~> 2.2.5'
  s.dependency 'TPKeyboardAvoiding', '~> 1.3.3'
  s.dependency 'OAuthSwift', '~> 2.1.0'
  s.dependency 'ReachabilitySwift', '~> 5.0.0'
  s.dependency 'Validator', '~> 3.2.1'
  s.dependency 'Firebase/Analytics', '~> 7.2.0'
  s.dependency 'Firebase/Crashlytics', '~> 7.2.0'
  s.dependency 'Firebase/Messaging', '~> 7.2.0'
  s.dependency 'PhoneNumberKit', '3.3.1'
  s.dependency 'CountryPickerView', '~> 3.1.2'
  s.dependency 'BLZJapx/RxCodableMoya', '~> 3.0.0'
  s.dependency 'UberSignature', '~> 1.0.3'
  s.dependency 'RxSwiftExt', '~> 5.2.0'
  s.dependency 'FYAMResearchKit', '~> 3.0.0'
  s.dependency 'Charts', '~> 3.6.0'
  s.dependency 'StepSlider', '~> 1.8.0'

  
  s.static_framework = true
  
end
