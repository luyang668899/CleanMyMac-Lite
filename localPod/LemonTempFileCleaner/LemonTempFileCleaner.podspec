Pod::Spec.new do |s|
  s.name             = 'LemonTempFileCleaner'
  s.version          = '1.0.0'
  s.summary          = 'Temporary file cleaner for macOS'
  s.description      = 'A powerful temporary file cleaner module for Tencent Lemon, designed to safely scan and remove temporary files from macOS systems.'
  s.homepage         = 'https://github.com/Tencent/Lemon'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tencent' => 'lemon@tencent.com' }
  s.source           = { :git => 'https://github.com/Tencent/Lemon.git', :tag => s.version.to_s }
  s.osx.deployment_target = '10.11'
  s.source_files     = 'LemonTempFileCleaner/Classes/**/*'
  s.public_header_files = 'LemonTempFileCleaner/Classes/**/*.h'
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
end