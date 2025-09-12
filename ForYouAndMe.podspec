#
# Be sure to run `pod lib lint ForYouAndMe.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ForYouAndMe'
  s.version          = '0.98.0'
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

  s.frameworks = 'UIKit'

  s.subspec 'Core' do |core|
    core.source_files = 'ForYouAndMe/Classes/**/*'
    core.resource_bundles = {
      'ForYouAndMe' => ['ForYouAndMe/Assets/**/*.{json,xcassets}']
    }
    
    core.vendored_frameworks = 'ForYouAndMe/Frameworks/MirSmartDevice.xcframework'
    
    # EMBED: script phase che copia e firma la slice corretta
    core.script_phases = [
      {
        :name => 'Embed MirSmartDevice.xcframework',
        :execution_position => :after_compile,
        :shell_path => '/bin/sh',
        :input_files => [
          '${PODS_TARGET_SRCROOT}/ForYouAndMe/Frameworks/MirSmartDevice.xcframework/ios-arm64/MirSmartDevice.framework/MirSmartDevice',
          '${PODS_TARGET_SRCROOT}/ForYouAndMe/Frameworks/MirSmartDevice.xcframework/ios-arm64_x86_64-simulator/MirSmartDevice.framework/MirSmartDevice'
        ],
        :output_files => [
          '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/MirSmartDevice.framework/MirSmartDevice'
        ],
        :script => <<-'SCRIPT'
  set -euo pipefail
  # All comments must be in English.

  # Prefer using PODS_TARGET_SRCROOT so it works both as dev pod and as installed pod.
  XCFRAMEWORK_ROOT="${PODS_TARGET_SRCROOT}/ForYouAndMe/Frameworks/MirSmartDevice.xcframework"
  DEST_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

  if [[ "${PLATFORM_NAME}" == "iphonesimulator" ]]; then
    SLICE_DIR="ios-arm64_x86_64-simulator"
  else
    SLICE_DIR="ios-arm64"
  fi

  SRC_FRAMEWORK="${XCFRAMEWORK_ROOT}/${SLICE_DIR}/MirSmartDevice.framework"

  echo "Embedding ${SRC_FRAMEWORK} -> ${DEST_DIR}"
  mkdir -p "${DEST_DIR}"
  rsync -a --delete "${SRC_FRAMEWORK}" "${DEST_DIR}"

  # Code sign if needed
  if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "${CODE_SIGNING_ALLOWED}" != "NO" ]]; then
    /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
      --preserve-metadata=identifier,entitlements \
      "${DEST_DIR}/MirSmartDevice.framework"
  fi
  SCRIPT
      }
    ]
    
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
