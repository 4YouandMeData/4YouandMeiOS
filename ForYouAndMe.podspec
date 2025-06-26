#
# Be sure to run `pod lib lint ForYouAndMe.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ForYouAndMe'
  s.version          = '0.96.4'
  s.summary          = 'Framework for research studies apps'
  s.description      = <<-DESC
                       ForYouAndMe is a framework aimed to easily develop an app for research study
  DESC

  s.homepage         = 'https://github.com/4YouandMeData/4YouandMeiOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Giuseppe Lapenta' => 'giuseppe@balzo.eu' }
  s.source           = { :git => 'https://github.com/4YouandMeData/4YouandMeiOS.git', :tag => s.version.to_s }

  s.cocoapods_version = '>= 1.6.0'

  s.ios.deployment_target = '15.6'

  s.swift_version = '5.2'

  s.static_framework = true

  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64 arm64'
  }

  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }

  s.xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/ForYouAndMe/Frameworks/**'
  }

  s.frameworks = 'UIKit'

  s.subspec 'Core' do |core|
    core.source_files = 'ForYouAndMe/Classes/**/*'
    core.resource_bundles = {
      'ForYouAndMe' => ['ForYouAndMe/Assets/**/*.{json,xcassets}']
    }
    core.vendored_frameworks = 'ForYouAndMe/Frameworks/MirSmartDevice.framework'
    core.dependency 'Moya/RxSwift', '~> 15.0.0'
    core.dependency 'Moya/ReactiveSwift', '~> 15.0.0'
    core.dependency 'AlamofireImage', '~> 4.3.0'
    core.dependency 'RxCocoa', '~> 6.0'
    core.dependency 'PureLayout', '~> 3.1.9'
    core.dependency 'SVProgressHUD', '~> 2.3.1'
    core.dependency 'TPKeyboardAvoiding', '~> 1.3.3'
    core.dependency 'OAuthSwift', '~> 2.1.2'
    core.dependency 'ReachabilitySwift', '~> 5.2.4'
    core.dependency 'Validator', '~> 3.2.1'
    core.dependency 'Firebase/Analytics', '~> 11.7.0'
    core.dependency 'Firebase/Crashlytics', '~> 11.7.0'
    core.dependency 'Firebase/Messaging', '~> 11.7.0'
    core.dependency 'PhoneNumberKit', '3.3.1'
    core.dependency 'CountryPickerView', '~> 3.1.2'
    core.dependency 'UberSignature', '~> 1.0.3'
    core.dependency 'RxSwiftExt', '~> 6.2.1'
    core.dependency 'FYAMResearchKit', '~> 3.0.0'
    core.dependency 'StepSlider', '~> 1.8.0'
    core.dependency 'BalzoGPUImage2', '~> 0.2.1'
    core.dependency 'JJFloatingActionButton', '~> 3.0.1'
  end

  s.subspec 'Terra' do |terra|
    terra.dependency 'TerraiOS', '~> 1.6.26'
  end
end
