Pod::Spec.new do |spec|
  spec.name         = "SammatiNoticeSDK"
  spec.version      = "1.0.0"
  spec.summary      = "Native iOS SDK for Sammati Consent & Notice Management"
  spec.description  = <<-DESC
                      SammatiNoticeSDK provides native Swift components for displaying consent notices,
                      capturing user consents, and handling minor & guardian consent flows.
                   DESC

  spec.homepage     = "https://github.com/YOUR_ORGANIZATION/SammatiNoticeSDK"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Sammati" => "support@sammati.io" }

  spec.platform     = :ios, "15.0"
  spec.swift_version = "5.9"

  spec.source       = { :git => "https://github.com/YOUR_ORGANIZATION/SammatiNoticeSDK.git", :tag => "#{spec.version}" }
  spec.source_files = "Sources/SammatiNoticeSDK/**/*.swift"
  spec.resource_bundles = {
    'SammatiNoticeSDK_Privacy' => ['Sources/SammatiNoticeSDK/PrivacyInfo.xcprivacy']
  }

  spec.frameworks   = "UIKit", "WebKit"
end
