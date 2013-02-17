//
//  main.m
//  Shell
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMShellMain.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        // insert code here...
        NSLog(@"Hello, World!");

//        [[MMShellMain sharedApplication] start];
        [[MMShellMain sharedApplication] executeCommand:@"/Users/mehdi/Development/Terminal/tmp/test"];
//        [[MMShellMain sharedApplication] executeCommand:@"/bin/bash"];

    }
    return 0;
}
