Pod::Spec.new do |s|
  s.name         = "LemonSystemCleaner"
  s.version      = "0.1.0"
  s.summary      = "系统数据安全清理模块"
  s.description  = <<-DESC
                   系统数据安全清理模块，专注于安全清理系统数据而不损坏系统文件
                   DESC
  s.homepage     = "https://lemon.qq.com"
  s.license      = "GPL"
  s.author       = { "Tencent" => "lemon@tencent.com" }
  s.platform     = :osx, "10.11"
  s.source       = { :path => "." }
  s.source_files  = "LemonSystemCleaner/Classes/**/*"
  s.frameworks = "Foundation"
  s.dependency "QMCoreFunction"
end
