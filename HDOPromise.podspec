Pod::Spec.new do |spec|

spec.name = "HDOPromise"
spec.version = "1.0.0"
spec.summary = "Promise/A+ spec implementation"
spec.homepage = "https://github.com/dannichols/HDOPromise"
spec.license = { type: 'MIT', file: 'LICENSE' }
spec.authors = { "Dan Nichols" => 'dan.nicho@gmail.com' }
pch_HDO = <<-EOS
#ifndef TARGET_OS_IOS
    #define TARGET_OS_IOS TARGET_OS_IPHONE
#endif
#ifndef TARGET_OS_WATCH
    #define TARGET_OS_WATCH 0
#endif
#ifndef TARGET_OS_TV
    #define TARGET_OS_TV 0
#endif
EOS
spec.prefix_header_contents = pch_HDO

spec.ios.deployment_target = '8.0'
spec.osx.deployment_target = '10.9'
spec.watchos.deployment_target = '2.0'
spec.tvos.deployment_target = '9.0'

spec.source = { git: "https://github.com/dannichols/HDOPromise.git", tag: "v#{spec.version}", submodules: true }
spec.source_files = "HDOPromise/HDOPromise/**/*.{h,swift}"

end