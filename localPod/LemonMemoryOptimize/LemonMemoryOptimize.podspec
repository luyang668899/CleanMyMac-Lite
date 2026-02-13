Pod::Spec.new do |s|
  s.name         = "LemonMemoryOptimize"
  s.version      = "0.1.0"
  s.summary      = "智能内存优化模块"
  s.description  = <<-DESC
                   智能内存优化模块，提供内存监控、智能内存释放等功能
                   DESC
  s.homepage     = "https://lemon.qq.com"
  s.license      = "GPL"
  s.author       = { "Tencent" => "lemon@tencent.com" }
  s.platform     = :osx, "10.11"
  s.source       = { :path => "." }
  s.source_files  = "LemonMemoryOptimize/Classes/**/*"
  s.frameworks = "Foundation", "AppKit"
  s.dependency "QMCoreFunction"
  s.dependency "LemonStat"
end
