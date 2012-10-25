KxMovie - movie player for iOS using ffmpeg
===========================================

### Build instructions:

First you need download, configure and build [FFmpeg](http://ffmpeg.org/index.html)
For this open console and type in
	
	cd kxmovie
	git submodule update
	git submodule foreach git pull
	rake

### Usage

See KxMovieExample demo project as example of using.
Remember, you need to copy some movies via iTunes for playing them.

	ViewController *vc;
	vc = [KxMovieViewController movieViewControllerWithContentPath:path error:nil];
	[self presentViewController:vc animated:YES completion:nil];

### Requirements

 at least iOS 5.1

### Screenshots:

![movie view](https://raw.github.com/kolyvan/kxmovie/master/screenshot-movie.png "Movie View")
![info view](https://raw.github.com/kolyvan/kxmovie/master/screenshot-info.png "Info View")

### Feedback

Tweet me — [@kolyvan_ru](http://twitter.com/kolyvan_ru).