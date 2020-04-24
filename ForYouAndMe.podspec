#
# Be sure to run `pod lib lint ForYouAndMe.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ForYouAndMe'
  s.version          = '0.4.0'
  s.summary          = 'Framework for research studies apps'
  s.description      = <<-DESC
                       ForYouAndMe is a framework aimed to easily develop an app for research study
  DESC

  s.homepage         = 'http://balzo.eu'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'LeonardoPasseri' => 'leonardo@balzo.eu' }
  s.source           = { :git => 'https://github.com/balzo-tech/4youandmeiOS.git', :tag => s.version.to_s }

  s.cocoapods_version = '>= 1.6.0'
  
  s.ios.deployment_target = '13.0'
  
  s.swift_version = "5.2"

  s.source_files = 'ForYouAndMe/Classes/**/*'
  
  s.resource_bundles = {
      'ForYouAndMe' => ['ForYouAndMe/Assets/*.xcassets']
  }
   
  s.frameworks = 'UIKit'
  
  s.dependency 'Moya/RxSwift', '~> 14.0.0'
  s.dependency 'Moya-ModelMapper/RxSwift', '~> 10.0.0'
  s.dependency 'PureLayout', '~> 3.1.5'
  s.dependency 'SVProgressHUD', '~> 2.2.5'
  s.dependency 'TPKeyboardAvoiding', '~> 1.3.3'
  s.dependency 'OAuthSwift', '~> 2.1.0'
  s.dependency 'ReachabilitySwift', '~> 5.0.0'
  s.dependency 'Validator', '~> 3.2.1'
  s.dependency 'Firebase/Analytics', '~> 6.21.0'
  s.dependency 'Firebase/Crashlytics', '~> 6.21.0'
  
  s.static_framework = true
  
end
