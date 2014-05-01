//
//  main.m
//  KxMovieExample
//
//  Created by Kolyvan on 25.10.12.
//
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

int main(int argc, char *argv[])
{
    @autoreleasepool {
#ifdef LoggerStartForBuildUser
        LoggerStartForBuildUser();
#endif
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
