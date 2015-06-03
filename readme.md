KxMovie - movie player for iOS using ffmpeg (modified by kinglonghuang)
===========================================

2015.6.3
Support arm64 and x86_64 architecture

### Build instructions:

First you need download, configure and build [FFmpeg](http://ffmpeg.org/index.html).
For this open console and type in
	
	cd kxmovie
	git submodule update --init	
	rake 
	
The rake command will firstly build all the architectures: the armv7, armv7s, arm64, i386, x86_64 architecture.
Then generate a debug version which contains all the architectures above, and a release version which only contains the armv7 and arm64 architecture.
<br>you can also using one of these cmds below to specify the architecture:

	rake build_ffmpeg_i386
	rake build_ffmpeg_x86
	rake build_ffmpeg_armv7
	rake build_ffmpeg_armv7s
	rake build_ffmpeg_arm64
	
Generally, the `rake` command is all you need :)

### Usage

1. Open the kxmovie.xcodeproj with Xcode and drop the kxmovie/ffmpeg_debug into your project. (using kxmovie/ffmpeg_relase instead for release)
2. Set the "header search path" to "ffmpeg_debug/include" folder, and choose the "recursive" options ((or "ffmpeg_release/include" for a release)

3. Command+B, enjoy yourself :)

Note: The sdk version is 8.3, you may need to change it ("SDK_VERSION" in Rakefile)

For play movies:

	ViewController *vc;
	vc = [KxMovieViewController movieViewControllerWithContentPath:path parameters:nil];
	[self presentViewController:vc animated:YES completion:nil];

See KxMovieExample demo project as example of using.

Also, you can include kxmovie as subproject.
Look at [kxtorrent](https://github.com/kolyvan/kxtorrent) as example.

Remember, you need to copy some movies via iTunes for playing them.
And you can use kxmovie for streaming from remote sources via rtsp,rtmp,http,etc.

### Requirements

at least iOS 6 and iPhone 4

### Feedback

Tweet me — [@kolyvan_ru](http://twitter.com/kolyvan_ru).
Email: kinglong_h@126.com
