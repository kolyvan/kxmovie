//
//  MainViewController.m
//  kxmovie
//
//  Created by Kolyvan on 18.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import "MainViewController.h"
#import "KxMovieViewController.h"
#import "KxMovieDecoder.h"

@interface KxMovieIOStreamFile : NSObject<KxMovieIOStream>
@end

@implementation KxMovieIOStreamFile {
    
    NSFileHandle *_fileHandle;
    UInt64       _fileSize;
}

- (BOOL) ioStreamOpen: (NSString *)path
{
    [self ioStreamClose];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSDictionary *attr =[fm attributesOfItemAtPath:path error:nil];
    if (!attr) {
        NSLog(@"ioStreamOpen, file not found");
        return NO;
    }
    
    if ([attr fileType] == NSFileTypeSymbolicLink) {
        
        path = [fm destinationOfSymbolicLinkAtPath:path error:nil];
        if (!path) {
        
            NSLog(@"ioStreamOpen, invalid symlink");
            return NO;
        }
        
        attr = [fm attributesOfItemAtPath:path error:nil];
    }
    
    _fileSize = [attr fileSize];
    if (!_fileSize) _fileSize = -1;
    
    _fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!_fileHandle) {
        NSLog(@"ioStreamOpen, unable open file");
        return NO;
    }
    
    //NSLog(@"ioStreamOpen, success");
    return YES;
}

- (void) ioStreamClose
{
    if (_fileHandle) {
        
        [_fileHandle closeFile];
        _fileHandle = nil;
        //NSLog(@"ioStreamClose");
    }
}

- (NSInteger) ioStreamReadBuffer: (Byte *) buffer bufSize: (NSInteger) bufSize
{
    NSData *data = nil;
    NSInteger result = -1;
    
    @try {
        data = [_fileHandle readDataOfLength:bufSize];
    } @catch (NSException *exp) {
        
        NSLog(@"exception during readBuffer: %@", exp);
    }
    
    if (data) {
        
        result = MIN(bufSize, data.length);
        memcpy(buffer, data.bytes, result);
    }
        
    //NSLog(@"readBuffer %d", result);
    return result;
}

- (NSInteger) ioStreamWriteBuffer: (Byte *) buffer bufSize: (NSInteger) bufSize
{
    return -1;
}

- (UInt64) ioStreamSeekOffset: (UInt64) offset whence: (NSInteger) whence
{
    UInt64 result = -1;
    
    @try {
        
        if (whence == SEEK_SET) {
            
            [_fileHandle seekToFileOffset:offset];
            result = _fileHandle.offsetInFile;
            
        } else if (whence == SEEK_CUR) {
            
            [_fileHandle seekToFileOffset:_fileHandle.offsetInFile + offset];
            result = _fileHandle.offsetInFile;
            
        } else if (whence == SEEK_END) {
            
            [_fileHandle seekToEndOfFile];
            [_fileHandle seekToFileOffset:_fileHandle.offsetInFile + offset];
            result = _fileHandle.offsetInFile;
        }
        
    } @catch (NSException *exp) {
        
        NSLog(@"exception during seekOffset: %@", exp);
    }
    
    //NSLog(@"seekOffset %lld", result);
    return result;
}

- (UInt64) ioStreamSize
{
    return _fileSize;
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

@interface MainViewController () {
    NSArray *_localMovies;
    NSArray *_remoteMovies;
}
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation MainViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.title = @"Movies";
        self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag: 0];
        
        _remoteMovies = @[

            @"http://eric.cast.ro/stream2.flv",
            @"http://liveipad.wasu.cn/cctv2_ipad/z.m3u8",                          
            @"http://www.wowza.com/_h264/BigBuckBunny_175k.mov",
            // @"http://www.wowza.com/_h264/BigBuckBunny_115k.mov",
            @"rtsp://184.72.239.149/vod/mp4:BigBuckBunny_115k.mov",
            @"http://santai.tv/vod/test/test_format_1.3gp",
            @"http://santai.tv/vod/test/test_format_1.mp4",
        
            //@"rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov",
            //@"http://santai.tv/vod/test/BigBuckBunny_175k.mov",
        
            @"rtmp://aragontvlivefs.fplive.net/aragontvlive-live/stream_normal_abt",
            @"rtmp://ucaster.eu:1935/live/_definst_/discoverylacajatv",
            @"rtmp://edge01.fms.dutchview.nl/botr/bunny.flv"
        ];
        
    }
    return self;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor whiteColor];
    //self.tableView.backgroundView = [[UIImageView alloc] initWithImage:image];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    [self.view addSubview:self.tableView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self reloadMovies];
    [self.tableView reloadData];
}

- (void) reloadMovies
{
    NSMutableArray *ma = [NSMutableArray array];
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask,
                                                            YES) lastObject];
    NSArray *contents = [fm contentsOfDirectoryAtPath:folder error:nil];
    
    for (NSString *filename in contents) {
        
        if (filename.length > 0 &&
            [filename characterAtIndex:0] != '.') {
            
            NSString *path = [folder stringByAppendingPathComponent:filename];
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr) {
                id fileType = [attr valueForKey:NSFileType];
                if ([fileType isEqual: NSFileTypeRegular] ||
                    [fileType isEqual: NSFileTypeSymbolicLink]) {
                    
                    NSString *ext = path.pathExtension.lowercaseString;
                    
                    if ([ext isEqualToString:@"mp3"] ||
                        [ext isEqualToString:@"caff"]||
                        [ext isEqualToString:@"aiff"]||
                        [ext isEqualToString:@"ogg"] ||
                        [ext isEqualToString:@"wma"] ||
                        [ext isEqualToString:@"m4a"] ||
                        [ext isEqualToString:@"m4v"] ||
                        [ext isEqualToString:@"wmv"] ||
                        [ext isEqualToString:@"3gp"] ||
                        [ext isEqualToString:@"mp4"] ||
                        [ext isEqualToString:@"mov"] ||
                        [ext isEqualToString:@"avi"] ||
                        [ext isEqualToString:@"mkv"] ||
                        [ext isEqualToString:@"mpeg"]||
                        [ext isEqualToString:@"mpg"] ||
                        [ext isEqualToString:@"flv"] ||
                        [ext isEqualToString:@"vob"]) {
                        
                        [ma addObject:path];
                    }
                }
            }
        }
    }
    
    _localMovies = [ma copy];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:     return @"Remote";
        case 1:     return @"Local";
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:     return _remoteMovies.count;
        case 1:     return _localMovies.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *path;
    
    if (indexPath.section == 0) {
        
        path = _remoteMovies[indexPath.row];
        
    } else {
        
        path = _localMovies[indexPath.row];
    }

    cell.textLabel.text = path.lastPathComponent;
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *path;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (indexPath.section == 0) {
        
        path = _remoteMovies[indexPath.row];
        
    } else {
        
        path = _localMovies[indexPath.row];
    }
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
    if ([path.pathExtension isEqualToString:@"wmv"])
        parameters[KxMovieParameterMinBufferedDuration] = @(5.0);
    
    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        parameters[KxMovieParameterDisableDeinterlacing] = @(YES);
    
    // disable buffering
    //parameters[KxMovieParameterMinBufferedDuration] = @(0.0f);
    //parameters[KxMovieParameterMaxBufferedDuration] = @(0.0f);
    
    if (indexPath.section == 1)
      parameters[KxMovieParameterIOStream] = [[KxMovieIOStreamFile alloc] init];
    
    KxMovieViewController *vc = [KxMovieViewController movieViewControllerWithContentPath:path
                                                                               parameters:parameters];
    [self presentViewController:vc animated:YES completion:nil];
    //[self.navigationController pushViewController:vc animated:YES];    
}

@end
