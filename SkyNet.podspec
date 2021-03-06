Pod::Spec.new do |s|
  s.name     = 'SkyNet'
  s.version  = '5.0.37'
  s.license  = 'MIT'
  s.summary  = 'A delightful iOS and OS X networking framework.'
  s.homepage = 'https://github.com/AFNetworking/AFNetworking'
  s.social_media_url = 'https://bitbucket.org'
  s.authors  = { 'Andrew Bradnan' => 'andrew@whirlygigventures.com' }
  s.source   = { :git => 'https://github.com/andrewbradnan/AFNetworking.git', :tag => s.version, :submodules => true }
  s.requires_arc = true
  
  s.source_files = 'SkyNet/**/*.{swift}'
    
  s.ios.deployment_target = '8.0'
  
  s.dependency 'FutureKit'
  s.dependency 'SwiftyJSON'
  s.dependency 'SwiftCommon'
  s.dependency 'SWXMLHash'

end
