require "pathname"
require "fileutils"

def system_or_exit(cmd, stdout = nil)
  puts "Executing #{cmd}"
  cmd += " >#{stdout}" if stdout
  system(cmd) or raise "******** Build failed ********"
end

## build ffmpeg

SDK_VERSION=''

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
'--arch=x86_64',
'--cpu=x86_64',
"--extra-ldflags='-arch x86_64 -miphoneos-version-min=8.0'",
"--extra-cflags='-arch x86_64 -miphoneos-version-min=8.0'",
'--disable-asm',
]


FFMPEG_BUILD_ARGS_ARM64 = [
'--arch=arm64',
# '--cpu=cortex-a9',
'--enable-pic',
"--extra-cflags='-arch arm64 -miphoneos-version-min=8.0'",
"--extra-ldflags='-arch arm64 -miphoneos-version-min=8.0'",
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

def mkArgs(platformPath, sdkPath, platformArgs, filepath)
	
	cc = '--cc=' + GCC_PATH
	path = '--prefix=./FFmpeg/' + filepath
	as = ""
	sysroot = '--sysroot=' + XCODE_PATH + platformPath + sdkPath
#	extra = '--extra-ldflags=-L' + XCODE_PATH + platformPath + sdkPath + LIB_PATH
	extra = ""
	args = FFMPEG_BUILD_ARGS + platformArgs
	args << path
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
	when 'x86_64'
		args = mkArgs(PLATOFRM_PATH_SIM, SDK_PATH_SIM, FFMPEG_BUILD_ARGS_SIM, 'x86_64')
	when 'arm64'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_ARM64, 'arm64')		
	else
		raise "Build failed: unknown arch: #{arch}"
	end
	
	dest = ensureDir('FFmpeg/' + arch)
	
	system_or_exit "cd FFmpeg; ./configure #{args}"
	system_or_exit "cd FFmpeg; make"	
	#moveLibs(dest)	
	system_or_exit "cd FFmpeg; [ -f -.d ] && rm -- -.d; make clean"

end

def mkLipoArgs(lib)
	"-create -arch arm64 arm64/lib/#{lib}.a -arch x86_64 x86_64/lib/#{lib}.a -output universal/lib/#{lib}.a"
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

desc "Build ffmpeg x86_64 libs"
task :build_ffmpeg_x86_64 do	
	buildArch('x86_64')	
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
	
	dest = ensureDir('libs/FFmpeg/lib/')

	FFMPEG_LIBS.each do |x|
		FileUtils.move Pathname.new("FFmpeg/universal/lib/#{x}.a"), dest
	end

	FileUtils.cp "FFmpeg/x86_64/include", "libs/FFmpeg"

end

##
task :clean => [:clean_ffmpeg]
task :build_ffmpeg => [:check_gas_preprocessor, :build_ffmpeg_arm64, :build_ffmpeg_x86_64, :build_ffmpeg_universal]
task :default => [:build_ffmpeg]