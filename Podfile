# Podfile for Scenic
platform :ios, '17.0'
use_frameworks!

target 'Scenic' do
  # Supabase
  pod 'Supabase', '~> 2.0'
  
  # Cloudinary
  pod 'Cloudinary', '~> 3.0'
  
  # Optional: Additional helpful pods
  pod 'KeychainSwift', '~> 20.0'  # For secure credential storage
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end