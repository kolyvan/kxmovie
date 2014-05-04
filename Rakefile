
require "pathname"
require "fileutils"

def system_or_exit(cmd, stdout = nil)
  puts "Executing #{cmd}"
  cmd += " >#{stdout}" if stdout
  system(cmd) or raise "******** Build failed ********"
end

## build ffmpeg

SDK_VERSION='7.1'

XCODE_PATH='/Applications/Xcode.app/Contents/Developer/Platforms'
GCC_PATH='/Applications/XCode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang'
LIB_PATH='/usr/lib/system'
GASPREP_DEST_PATH='/usr/local/bin'
PLATOFRM_PATH_SIM ='/iPhoneSimulator.platform'
PLATOFRM_PATH_IOS ='/iPhoneOS.platform'
SDK_PATH_SIM="/Developer/SDKs/iPhoneSimulator#{SDK_VERSION}.sdk"
SDK_PATH_IOS="/Developer/SDKs/iPhoneOS#{SDK_VERSION}.sdk"


FFMPEG_BUILD_ARGS_SIM = [
'--assert-level=2',
'--disable-mmx',
'--arch=i386',
'--cpu=i386',
"--extra-ldflags='-arch i386 -miphoneos-version-min=6.0'",
"--extra-cflags='-arch i386 -miphoneos-version-min=6.0'",
'--disable-asm',
]

FFMPEG_BUILD_ARGS_ARMV7 = [
'--arch=arm',
'--cpu=cortex-a8',
'--enable-pic',
"--extra-cflags='-arch armv7 -miphoneos-version-min=6.0'",
"--extra-ldflags='-arch armv7 -miphoneos-version-min=6.0'",
"--extra-cflags='-mfpu=neon -mfloat-abi=softfp'",
'--enable-neon',
# '--disable-neon',
'--enable-optimizations',
'--disable-debug',
'--disable-armv5te',
'--disable-armv6',
'--disable-armv6t2',
'--enable-small',
]

FFMPEG_BUILD_ARGS_ARMV7S = [
'--arch=arm',
'--cpu=cortex-a9',
'--enable-pic',
"--extra-cflags='-arch armv7s -miphoneos-version-min=6.0'",
"--extra-ldflags='-arch armv7s -miphoneos-version-min=6.0'",
"--extra-cflags='-mfpu=neon -mfloat-abi=softfp'",
'--enable-neon',
# '--disable-neon',
'--enable-optimizations',
'--disable-debug',
'--disable-armv5te',
'--disable-armv6',
'--disable-armv6t2',
'--enable-small',
]

FFMPEG_BUILD_ARGS_ARM64 = [
'--arch=arm64',
# '--cpu=cortex-a9',
'--enable-pic',
"--extra-cflags='-arch arm64 -miphoneos-version-min=6.0'",
"--extra-ldflags='-arch arm64 -miphoneos-version-min=6.0'",
"--extra-cflags='-mfpu=neon -mfloat-abi=softfp'",
'--enable-neon',
# '--disable-neon',
'--enable-optimizations',
'--disable-debug',
'--disable-armv5te',
'--disable-armv6',
'--disable-armv6t2',
'--enable-small',
]

FFMPEG_BUILD_ARGS = [
'--disable-ffmpeg',
'--disable-ffplay',
'--disable-ffserver',
'--disable-ffprobe',
'--disable-doc',
'--disable-bzlib',
'--target-os=darwin',
'--enable-cross-compile',
#'--enable-nonfree',
# '--enable-gpl',
'--enable-version3',
]

FFMPEG_LIBS = [
'libavcodec',
'libavformat',
'libavutil',
'libswscale',
'libswresample',
]

def mkArgs(platformPath, sdkPath, platformArgs)
	
	cc = '--cc=' + GCC_PATH
	as = ""
	sysroot = '--sysroot=' + XCODE_PATH + platformPath + sdkPath
#	extra = '--extra-ldflags=-L' + XCODE_PATH + platformPath + sdkPath + LIB_PATH
	extra = ""
	args = FFMPEG_BUILD_ARGS + platformArgs
	args << cc 
	args << as
	args << sysroot
	args << extra
	
	args.join(' ')
end

def moveLibs(dest)
	FFMPEG_LIBS.each do |x|
		FileUtils.move Pathname.new("FFmpeg/#{x}/#{x}.a"), dest		
	end
end

def ensureDir(path)

	dest = Pathname.new path
	if dest.exist?
		FileUtils.rm Dir.glob("#{path}/*.a")
	else
		dest.mkpath
	end

	dest
end

def buildArch(arch)

	case arch
	when 'i386'
		args = mkArgs(PLATOFRM_PATH_SIM, SDK_PATH_SIM, FFMPEG_BUILD_ARGS_SIM)
	when 'armv7'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_ARMV7)
	when 'armv7s'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_ARMV7S)		
	when 'arm64'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_ARM64)		
	else
		raise "Build failed: unknown arch: #{arch}"
	end
	
	dest = ensureDir('FFmpeg/' + arch)
	
	system_or_exit "cd FFmpeg; ./configure #{args}"
	system_or_exit "cd FFmpeg; make"	
	moveLibs(dest)	
	system_or_exit "cd FFmpeg; [ -f -.d ] && rm -- -.d; make clean"

end

def mkLipoArgs(lib)
	"-create -arch armv7 armv7/#{lib}.a -arch armv7 armv7s/#{lib}.a -arch arm64 arm64/#{lib}.a -arch i386 i386/#{lib}.a -output universal/#{lib}.a"
end

desc "check gas-preprocessor.pl"
task :check_gas_preprocessor do	

	found = false

	ENV['PATH'].split(':').each do |x|
		p = Pathname.new(x) + 'gas-preprocessor.pl'
		if p.exist? && p.writable?
			found = true
			break;
		end
	end

	unless found
    # See http://stackoverflow.com/questions/5056600/how-to-install-gas-preprocessor for more info.
    puts "Installing the gas-preprocessor to #{GASPREP_DEST_PATH}"
    
    FileUtils.move Pathname.new("gas-preprocessor/gas-preprocessor.pl"), Pathname.new(GASPREP_DEST_PATH)
  	system_or_exit "chmod +x #{GASPREP_DEST_PATH}/gas-preprocessor.pl"
    
    # raise "Build failed: first install gas-preprocessor.pl.\nSee http://stackoverflow.com/questions/5056600/how-to-install-gas-preprocessor for more info."
	end

end

desc "Clean ffmpeg"
task :clean_ffmpeg do
	system_or_exit "cd FFmpeg; [ -f -.d ] && rm -- -.d; make clean"
end

desc "Build ffmpeg i386 libs"
task :build_ffmpeg_i386 do	
	buildArch('i386')	
end

desc "Build ffmpeg armv7 libs"
task :build_ffmpeg_armv7 do	
	buildArch('armv7')	
end

desc "Build ffmpeg armv7s libs"
task :build_ffmpeg_armv7s do	
	buildArch('armv7s')	
end

desc "Build ffmpeg arm64 libs"
task :build_ffmpeg_arm64 do	
	buildArch('arm64')	
end

desc "Build ffmpeg universal libs"
task :build_ffmpeg_universal do	

	ensureDir('FFmpeg/universal')
	
	FFMPEG_LIBS.each do |x|
		args = mkLipoArgs(x)
		system_or_exit "cd FFmpeg; xcrun -sdk iphoneos lipo #{args}"
	end
	
	dest = ensureDir('libs/FFmpeg/')

	FFMPEG_LIBS.each do |x|
		FileUtils.move Pathname.new("FFmpeg/universal/#{x}.a"), dest
	end

end

## build libkxmovie

def cleanMovieLib(config)
	buildDir = Pathname.new 'tmp/build'	
  	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration #{config} -sdk iphoneos#{SDK_VERSION} clean SYMROOT=#{buildDir}"
	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration #{config} -sdk iphonesimulator#{SDK_VERSION} clean SYMROOT=#{buildDir}"  	
end

desc "Clean libkxmovie-debug"
task :clean_movie_debug do
	cleanMovieLib 'Debug'
end

desc "Clean libkxmovie-release"
task :clean_movie_release do
	cleanMovieLib 'Release'
end

desc "Build libkxmovie-debug"
task :build_movie_debug do
	buildDir = Pathname.new 'tmp/build'
	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration Debug -sdk iphoneos#{SDK_VERSION} build SYMROOT=#{buildDir} -arch armv7s"			
	FileUtils.move Pathname.new('tmp/build/Debug-iphoneos/libkxmovie.a'), Pathname.new('tmp/build/Debug-iphoneos/libkxmovie_armv7s.a')	

	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration Debug -sdk iphoneos#{SDK_VERSION} build SYMROOT=#{buildDir} -arch armv7"		
	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration Debug -sdk iphonesimulator#{SDK_VERSION} build SYMROOT=#{buildDir}"	
	system_or_exit "lipo -create -arch armv7 tmp/build/Debug-iphoneos/libkxmovie.a -arch armv7 tmp/build/Debug-iphoneos/libkxmovie_armv7s.a -arch i386 tmp/build/Debug-iphonesimulator/libkxmovie.a -output tmp/build/libkxmovie.a"
end

desc "Build libkxmovie-release"
task :build_movie_release do
	buildDir = Pathname.new 'tmp/build'
	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration Release -sdk iphoneos#{SDK_VERSION} build SYMROOT=#{buildDir} -arch armv7s"	
	FileUtils.move Pathname.new('tmp/build/Release-iphoneos/libkxmovie.a'), Pathname.new('tmp/build/Release-iphoneos/libkxmovie_armv7s.a')	

	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration Release -sdk iphoneos#{SDK_VERSION} build SYMROOT=#{buildDir} -arch armv7"	
	system_or_exit "xcodebuild -project kxmovie.xcodeproj -target kxmovie -configuration Debug -sdk iphonesimulator#{SDK_VERSION} build SYMROOT=#{buildDir}"	
	system_or_exit "lipo -create -arch armv7 tmp/build/Release-iphoneos/libkxmovie.a -arch armv7 tmp/build/Release-iphoneos/libkxmovie_armv7s.a -arch i386 tmp/build/Debug-iphonesimulator/libkxmovie.a -output tmp/build/libkxmovie.a"
	
	#FileUtils.copy Pathname.new('tmp/build/Release-iphoneos/libkxmovie.a'), buildDir
end

desc "Copy to output folder"
task :copy_movie do	
	dest = ensureDir 'output'	
	FileUtils.move Pathname.new('tmp/build/libkxmovie.a'), dest		
	FileUtils.copy Pathname.new('libs/FFmpeg/libavcodec.a'), dest
	FileUtils.copy Pathname.new('libs/FFmpeg/libavformat.a'), dest
	FileUtils.copy Pathname.new('libs/FFmpeg/libavutil.a'), dest
	FileUtils.copy Pathname.new('libs/FFmpeg/libswscale.a'), dest
	FileUtils.copy Pathname.new('libs/FFmpeg/libswresample.a'), dest
	FileUtils.copy Pathname.new('kxmovie/KxMovieViewController.h'), dest	
	FileUtils.copy Pathname.new('kxmovie/KxAudioManager.h'), dest	
	FileUtils.copy Pathname.new('kxmovie/KxMovieDecoder.h'), dest
	FileUtils.copy_entry Pathname.new('kxmovie/kxmovie.bundle'), dest + 'kxmovie.bundle'
end	

##
task :clean => [:clean_movie_debug, :clean_movie_release, :clean_ffmpeg]
task :build_ffmpeg => [:check_gas_preprocessor, :build_ffmpeg_armv7, :build_ffmpeg_armv7s, :build_ffmpeg_arm64, :build_ffmpeg_i386, :build_ffmpeg_universal]
#task :build_movie => [:build_movie_debug, :copy_movie] 
task :build_movie => [:build_movie_release, :copy_movie] 
task :build_all => [:build_ffmpeg, :build_movie] 
# task :default => [:build_all]
task :default => [:build_ffmpeg]
