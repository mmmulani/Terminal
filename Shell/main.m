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

        NSInteger identifier = [[NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding] intValue];
        MMLog(@"Starting Shell with identifier: %ld", (long)identifier);
        [[MMShellMain sharedApplication] startWithIdentifier:identifier];

    }
    return 0;
}
