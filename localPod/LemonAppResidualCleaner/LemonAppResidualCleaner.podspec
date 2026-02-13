Pod::Spec.new do |s|
  s.name             = 'LemonAppResidualCleaner'
  s.version          = '1.0.0'
  s.summary          = 'Application uninstallation residual cleaner for macOS'
  s.description      = 'A powerful application residual cleaner module for Tencent Lemon, designed to safely scan and remove residual files from uninstalled applications on macOS systems.'
  s.homepage         = 'https://github.com/Tencent/Lemon'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tencent' => 'lemon@tencent.com' }
  s.source           = { :git => 'https://github.com/Tencent/Lemon.git', :tag => s.version.to_s }
  s.osx.deployment_target = '10.11'
  s.source_files     = 'LemonAppResidualCleaner/Classes/**/*'
  s.public_header_files = 'LemonAppResidualCleaner/Classes/**/*.h'
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
end