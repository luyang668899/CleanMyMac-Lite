Pod::Spec.new do |s|
  s.name         = "LemonLoginItemOptimizer"
  s.version      = "0.1.0"
  s.summary      = "启动项智能排序优化模块"
  s.description  = <<-DESC
                   启动项智能排序优化模块，提供启动项分析、优化排序、延迟启动等功能
                   DESC
  s.homepage     = "https://lemon.qq.com"
  s.license      = "GPL"
  s.author       = { "Tencent" => "lemon@tencent.com" }
  s.platform     = :osx, "10.11"
  s.source       = { :path => "." }
  s.source_files  = "LemonLoginItemOptimizer/Classes/**/*"
  s.frameworks = "Foundation"
  s.dependency "QMAppLoginItemManage"
  s.dependency "QMCoreFunction"
end
