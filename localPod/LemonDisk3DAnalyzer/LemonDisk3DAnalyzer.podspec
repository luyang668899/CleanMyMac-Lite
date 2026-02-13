Pod::Spec.new do |s|
  s.name         = "LemonDisk3DAnalyzer"
  s.version      = "0.1.0"
  s.summary      = "3D磁盘空间分析模块"
  s.description  = <<-DESC
                   3D磁盘空间分析模块，提供磁盘空间的3D可视化展示和分析功能
                   DESC
  s.homepage     = "https://lemon.qq.com"
  s.license      = "GPL"
  s.author       = { "Tencent" => "lemon@tencent.com" }
  s.platform     = :osx, "10.11"
  s.source       = { :path => "." }
  s.source_files  = "LemonDisk3DAnalyzer/Classes/**/*"
  s.frameworks = "Foundation", "SceneKit", "AppKit"
  s.dependency "QMCoreFunction"
end
