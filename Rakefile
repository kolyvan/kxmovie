#Created by kolyvan_ru. @ https://github.com/kolyvan/kxmovie
#Modified by kinglonghuang @ https://github.com/kinglonghuang/kxmovie

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
PLATOFRM_PATH_SIM ='/iPhoneSimulator.platform'
PLATOFRM_PATH_IOS ='/iPhoneOS.platform'
SDK_PATH_SIM ="/Developer/SDKs/iPhoneSimulator#{SDK_VERSION}.sdk"
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
'--enable-optimizations',
'--disable-debug',
'--disable-armv5te',
'--disable-armv6',
'--disable-armv6t2',
'--enable-small',
]

FFMPEG_BUILD_ARGS_ARM64 = [
'--arch=arm64',
'--enable-pic',
"--extra-cflags='-arch arm64 -miphoneos-version-min=6.0'",
"--extra-ldflags='-arch arm64 -miphoneos-version-min=6.0'",
"--extra-cflags='-mfpu=neon -mfloat-abi=softfp'",
'--enable-neon',
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
'--enable-version3',
]

FFMPEG_LIBS = [
'libavcodec',
'libavdevice',
'libavfilter',
'libavformat',
'libavutil',
'libswresample',
'libswscale',
]

def mkArgs(platformPath, sdkPath, platformArgs,prefixDir)
	
	cc = '--cc=' + GCC_PATH
	as = ""
	sysroot = '--sysroot=' + XCODE_PATH + platformPath + sdkPath
	extra = ""
	prefix = '--prefix=' + "#{prefixDir}"
	args = FFMPEG_BUILD_ARGS + platformArgs
	args << cc 
	args << as
	args << sysroot
	args << extra
	args << prefix

	args.join(' ')
end

def ensureDir(path)

	dest = Pathname.new path
	if dest.exist?
		FileUtils.rm Dir.glob("#{path}/*.a")
	else
		dest.mkdir
	end

	dest
end

def buildArch(arch)
	prefixDir = ensureDir(ENV['PWD'] + "/kxmovie/ffmpeg_" + arch)
	
	case arch
	when 'i386'
		args = mkArgs(PLATOFRM_PATH_SIM, SDK_PATH_SIM, FFMPEG_BUILD_ARGS_SIM, prefixDir)
	when 'armv7'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_ARMV7, prefixDir)
	when 'armv7s'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_ARMV7S, prefixDir)		
	when 'arm64'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_ARM64, prefixDir)	
	else
		raise "Build failed: unknown arch: #{arch}"
	end
	
	system_or_exit "cd ffmpeg; ./configure #{args}"
	system_or_exit "cd ffmpeg; make"	
	system_or_exit "cd ffmpeg; make install"
	system_or_exit "cd ffmpeg; make clean"
	system_or_exit "rm -r #{prefixDir}/lib/pkgconfig"

end

def mkLipoArgs(lib, armv7Path, armv7sPath, arm64Path, i386Path, outputPath)
	"-create -arch armv7 #{armv7Path}/#{lib}.a -arch armv7 #{armv7sPath}/#{lib}.a -arch arm64 #{arm64Path}/#{lib}.a -arch i386 #{i386Path}/#{lib}.a -output #{outputPath}/#{lib}.a"
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
		raise "Build failed: first install gas-preprocessor.pl.\nSee http://stackoverflow.com/questions/5056600/how-to-install-gas-preprocessor for more info."
	end

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
	ensureDir(ENV['PWD'] + "/kxmovie/ffmpeg_" + "universal")
	cpySrc = ENV['PWD'] + "/kxmovie/ffmpeg_armv7/*"
	cpyDest = ensureDir(ENV['PWD'] + "/kxmovie/ffmpeg_universal")	
	system_or_exit "cp -r #{cpySrc} #{cpyDest}"

	srddc = ENV['PWD'] + "/kxmovie/ffmpeg_armv7/lib"
	armv7sPath = ENV['PWD']+"/kxmovie/ffmpeg_armv7s/lib"
	arm64Path = ENV['PWD']+"/kxmovie/ffmpeg_arm64/lib"
	i386Path = ENV['PWD']+"/kxmovie/ffmpeg_i386/lib"
	universalLibPath = "#{cpyDest}/lib" 
	FFMPEG_LIBS.each do |x|
		args = mkLipoArgs(x, srddc, armv7sPath, arm64Path,i386Path, universalLibPath)
		system_or_exit "lipo #{args}"
	end
end

##
task :build_ffmpeg => [:check_gas_preprocessor, :build_ffmpeg_i386, :build_ffmpeg_armv7, :build_ffmpeg_armv7s, :build_ffmpeg_arm64, :build_ffmpeg_universal]
task :default => [:build_ffmpeg]
