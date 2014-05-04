FFmpegPlayer-iOS - A movie player for iOS based on FFmpeg.
==========================================================

### Build Instructions

First you need to download, configure and build [FFmpeg](http://ffmpeg.org/index.html). For this, open console and type in:
	
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

Also, you can include kxmovie as subproject. Look at [kxtorrent](https://github.com/kolyvan/kxtorrent) as example.

Remember, you need to copy some movies via iTunes for playing them. And you can use kxmovie for streaming from remote sources via rtsp, rtmp, http, etc.

### Requirements

At least iOS 7.0 and iPhone 4 (because of iOS 7 requirements).

### Screenshots

<img src="https://raw.github.com/atelierdumobile/FFmpegPlayer-iOS/master/readme-media/screenshot-movie.png" alt="Movie View" width="50%">
<img src="https://raw.github.com/atelierdumobile/FFmpegPlayer-iOS/master/readme-media/screenshot-info.png" alt="Info View" width="50%">
<img src="https://raw.github.com/atelierdumobile/FFmpegPlayer-iOS/master/readme-media/screenshot-movie-landscape.png" alt="Movie View Landscape" width="50%">

### Feedback

Tweet me — [@kolyvan_ru](http://twitter.com/kolyvan_ru).

Tweet me — [@MonsieurDart](http://twitter.com/MonsieurDart).
