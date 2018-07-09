Pod::Spec.new do |s|
  s.name         = "GMCMultiImage"
  s.version      = "2.0.0"
  s.summary      = "GMCMultiImage is a set of classes you can use to show pictures for which you have multiple images in a range of sizes."
  s.author       = 'Hilton Campbell'
  s.homepage     = "https://github.com/GalacticMegacorp/GMCMultiImage"
  s.license      = 'MIT'
  s.source       = { :git => "https://github.com/GalacticMegacorp/GMCMultiImage.git", :tag => s.version.to_s }
  s.platforms    = { :ios => "10.0", :tvos => "10.0" }
  s.source_files = 'GMCMultiImage/*.{swift}'
  s.requires_arc = true
  s.frameworks   = 'UIKit'
  s.swift_version = '4.1'
end
