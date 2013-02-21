//
//  MMShared.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/20/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMShared.h"
#import <pthread.h>

NSString *const ConnectionShellName = @"com.mm.shell";
NSString *const ConnectionTerminalName = @"com.mm.terminal";

@implementation MMShared

+ (void)logMessage:(NSString *)format, ...;
{
    NSString *processName = [[NSProcessInfo processInfo] processName];
    va_list args;
    va_start(args, format);
    NSString *message = [NSString stringWithFormat:[@"%@[%ld:%lx] " stringByAppendingString:format], processName, (long)getpid(), (long)pthread_mach_thread_np(pthread_self()), args];
    va_end(args);

    dispatch_async(dispatch_get_current_queue(), ^{
        NSProxy *proxy = [[NSConnection connectionWithRegisteredName:ConnectionTerminalName host:nil] rootProxy];
        [proxy performSelector:@selector(_logMessage:) withObject:message];
    });
}

@end
