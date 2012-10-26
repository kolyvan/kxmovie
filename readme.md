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
2. Add frameworks: MediaPlayer, CoreAudio, AudioToolbox, Accelerate, QuartzCore, OpenGLES and libz.dylib

For play movies:

	ViewController *vc;
	vc = [KxMovieViewController movieViewControllerWithContentPath:path error:nil];
	[self presentViewController:vc animated:YES completion:nil];

Also, see KxMovieExample demo project as example of using.
Remember, you need to copy some movies via iTunes for playing them.

### Requirements

at least iOS 5.1 and iPhone 3GS 

### Screenshots:

![movie view](https://raw.github.com/kolyvan/kxmovie/master/screenshot-movie.png "Movie View")
![info view](https://raw.github.com/kolyvan/kxmovie/master/screenshot-info.png "Info View")

### Feedback

Tweet me — [@kolyvan_ru](http://twitter.com/kolyvan_ru).