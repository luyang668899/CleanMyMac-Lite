Pod::Spec.new do |s|
  s.name         = "LemonCacheCleaner"
  s.version      = "1.0.0"
  s.summary      = "Cache cleaner for Tencent Lemon Cleaner"
  s.description  = <<-DESC
                   A powerful cache cleaner module for Tencent Lemon Cleaner, 
                   which can scan, analyze and safely clean cache files on macOS.
                   DESC

  s.homepage     = "https://github.com/Tencent/Lemon-Cleaner"
  s.license      = { :type => "GPL v3", :file => "LICENSE" }
  s.author       = { "Tencent" => "support@tencent.com" }
  s.platform     = :osx, "10.10"

  s.source       = { :git => "https://github.com/Tencent/Lemon-Cleaner.git", :tag => s.version.to_s }
  s.source_files  = "LemonCacheCleaner/Classes/**/*"
  s.public_header_files = "LemonCacheCleaner/Classes/**/*.h"

  s.frameworks = "Foundation"

  s.requires_arc = true
end
