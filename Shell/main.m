//
//  main.m
//  Shell
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMShellMain.h"
#import "MMShared.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {

        NSInteger terminalIdentifier = [[NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding] integerValue];
        NSInteger shellIdentifier = [[NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding] integerValue];
        MMLog(@"Starting Shell with terminal identifier: %ld, shell identifier: %ld", terminalIdentifier, shellIdentifier);
        [[MMShellMain sharedApplication] startWithTerminalIdentifier:terminalIdentifier shellIdentifer:shellIdentifier];

    }
    return 0;
}
