
require "pathname"
require "fileutils"

def system_or_exit(cmd, stdout = nil)
  puts "Executing #{cmd}"
  cmd += " >#{stdout}" if stdout
  system(cmd) or raise "******** Build failed ********"
end

XCODE_PATH='/Applications/Xcode.app/Contents/Developer/Platforms'
GCC_PATH='/Developer/usr/bin/gcc'
LIB_PATH='/usr/lib/system'
PLATOFRM_PATH_SIM ='/iPhoneSimulator.platform'
PLATOFRM_PATH_IOS ='/iPhoneOS.platform'
SDK_PATH_SIM ='/Developer/SDKs/iPhoneSimulator5.1.sdk'
SDK_PATH_IOS='/Developer/SDKs/iPhoneOS6.0.sdk'

FFMPEG_BUILD_ARGS_SIM = [
'--assert-level=2',
'--disable-mmx',
'--arch=i386',
'--cpu=i386',
"--extra-ldflags='-arch i386'",
"--extra-cflags='-arch i386'",
]

FFMPEG_BUILD_ARGS_IOS = [
'--arch=arm',
'--cpu=cortex-a8',
"--extra-cflags='-arch armv7'",
"--extra-ldflags='-arch armv7'",
'--enable-pic',
]

FFMPEG_BUILD_ARGS = [
'--disable-asm',
'--disable-ffmpeg',
'--disable-ffplay',
'--disable-ffserver',
'--disable-ffprobe',
'--disable-doc',
'--disable-bzlib',
'--target-os=darwin',
'--enable-cross-compile',
]

FFMPEG_LIBS = [
'libavcodec',
'libavdevice',
'libavformat',
'libavutil',
'libswscale',
'libswresample',
]

def mkArgs(platformPath, sdkPath, platformArgs)
	
	cc = '--cc=' + XCODE_PATH + platformPath + GCC_PATH
	as = "--as='" + 'gas-preprocessor.pl ' + XCODE_PATH + platformPath + GCC_PATH + "'"
	sysroot = '--sysroot=' + XCODE_PATH + platformPath + sdkPath
	extra = '--extra-ldflags=-L' + XCODE_PATH + platformPath + sdkPath + LIB_PATH

	args = FFMPEG_BUILD_ARGS + platformArgs
	args << cc 
	args << as
	args << sysroot
	args << extra
	
	args.join(' ')
end

def moveLibs(dest)
	FFMPEG_LIBS.each do |x|
		FileUtils.move Pathname.new("ffmpeg/#{x}/#{x}.a"), dest		
	end
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

	case arch
	when 'i386'
		args = mkArgs(PLATOFRM_PATH_SIM, SDK_PATH_SIM, FFMPEG_BUILD_ARGS_SIM)
	when 'armv7'
		args = mkArgs(PLATOFRM_PATH_IOS, SDK_PATH_IOS, FFMPEG_BUILD_ARGS_IOS)
	else
		raise "Build failed: unknown arch: #{arch}"
	end
	
	dest = ensureDir('ffmpeg/' + arch)
	
	system_or_exit "cd ffmpeg; make clean"
	system_or_exit "cd ffmpeg; ./configure #{args}"
	system_or_exit "cd ffmpeg; make"	
	
	moveLibs(dest)	
end

def mkLipoArgs(lib)
	"-create -arch armv7 armv7/#{lib}.a -arch i386 i386/#{lib}.a -output universal/#{lib}.a"
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

desc "Build ffmpeg universal libs"
task :build_ffmpeg_universal do	

	ensureDir('ffmpeg/universal')
	
	FFMPEG_LIBS.each do |x|
		args = mkLipoArgs(x)
		system_or_exit "cd ffmpeg; lipo #{args}"
	end
	
	dest = ensureDir('libs')

	FFMPEG_LIBS.each do |x|
		FileUtils.move Pathname.new("ffmpeg/universal/#{x}.a"), dest
	end

end

task :build_ffmpeg => [:check_gas_preprocessor, :build_ffmpeg_i386, :build_ffmpeg_armv7, :build_ffmpeg_universal ]
task :default => [:build_ffmpeg ]
