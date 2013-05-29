//
//  MMShared.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/20/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMShared.h"
#import <pthread.h>

#ifdef DEBUG
NSString *const ConnectionShellName = @"com.mm.shelldebug";
NSString *const ConnectionTerminalName = @"com.mm.terminaldebug";
#else
NSString *const ConnectionShellName = @"com.mm.shell";
NSString *const ConnectionTerminalName = @"com.mm.terminal";
#endif

void MMLog(NSString *format, ...)
{
    static NSString *processName;
    if (!processName) {
        processName = [[NSProcessInfo processInfo] processName];
    }
    static NSDateFormatter *dateFormatter;
    if (!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    }
    NSString *now = [dateFormatter stringFromDate:[NSDate date]];
    va_list args;
    va_start(args, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *message = [NSString stringWithFormat:@"%@ %@[%ld:%lx] %@", now, processName, (long)getpid(), (long)pthread_mach_thread_np(pthread_self()), formattedString];

    dispatch_async(dispatch_get_current_queue(), ^{
        NSProxy *proxy = [[NSConnection connectionWithRegisteredName:ConnectionTerminalName host:nil] rootProxy];
        [proxy performSelector:@selector(_logMessage:) withObject:message];
    });
}

@implementation MMShared

@end
