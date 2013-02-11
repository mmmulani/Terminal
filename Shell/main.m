//
//  main.m
//  Shell
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        // insert code here...
        NSLog(@"Hello, World!");

        NSProxy *proxy = [[NSConnection connectionWithRegisteredName:@"terminal" host:nil] rootProxy];

        [proxy performSelector:@selector(beep:) withObject:@"Child sending beep!"];
        NSLog(@"Logging beep.");

        [[NSRunLoop mainRunLoop] run];
        
    }
    return 0;
}
