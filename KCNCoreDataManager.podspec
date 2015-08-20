Pod::Spec.new do |s|
  s.name             = "KCNCoreDataManager"
  s.version          = "1.0.0"
  s.summary          = "Core data manager"
  s.homepage         = "https://github.com/kevinnguy/KCNCoreDataManager"
  s.license          = 'MIT'
  s.authors          = { 'Kevin Nguy' => 'kevnguy@gmail.com' }
  s.source           = { :git => "https://github.com/kevinnguy/KCNCoreDataManager.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/kevnguy'

  s.platform     = :ios
  s.ios.deployment_target = '7.0'

  s.source_files = 'Classes'
end
