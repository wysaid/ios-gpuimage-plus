
Pod::Spec.new do |s|

  s.name         = "cge"
  s.version      = "3.0.0"
  s.summary      = "cge source code"
  s.description  = <<-DESC
libCGE
                   DESC

  s.homepage     = "https://github.com/wysaid/ios-gpuimage-plus"

  s.license      = "MIT"
  s.author       = { "wysaid" => "admin@wysaid.org" }
  s.platform     = :ios, "7.0"

  s.source       = { :git => "https://github.com/wysaid/ios-gpuimage-plus.git", :tag => "#{s.version}" }
  
  s.prefix_header_file = 'library/cge/libCGE-Prefix.pch'

  s.source_files = 'library/cge/**/*.{h,hpp,c,cpp,mm,m}'
  s.ios.framework = 'MobileCoreServices'
end
