KxMovie - movie player for iOS using ffmpeg
===========================================

### Build instructions:

First you need download, configure and build [FFmpeg](http://ffmpeg.org/index.html).
For this open console and type in
	
	cd kxmovie
	git submodule update --init	
	rake

### Usage

1. Drop files from kxmovie/output folder in your project.
2. Add frameworks: MediaPlayer, CoreAudio, AudioToolbox, Accelerate, QuartzCore, OpenGLES and libz.dylib .
3. Add libs: libkxmovie.a, libavcodec.a, libavformat.a, libavutil.a, libswscale.a, libswresample.a

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

at least iOS 5.1 and iPhone 3GS 

### Screenshots:

![movie view](https://raw.github.com/kolyvan/kxmovie/master/screenshot-movie.png "Movie View")
![info view](https://raw.github.com/kolyvan/kxmovie/master/screenshot-info.png "Info View")

### Feedback

Tweet me — [@kolyvan_ru](http://twitter.com/kolyvan_ru).