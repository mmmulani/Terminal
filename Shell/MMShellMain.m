//
//  MMShellMain.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMShellMain.h"
#import "MMShared.h"

@implementation MMShellMain

+ (MMShellMain *)sharedApplication;
{
    static MMShellMain *application;
    @synchronized(self) {
        if (!application) {
            application = [[MMShellMain alloc] init];
        }
    }

    return application;
}

- (void)start;
{
    self.shellConnection = [NSConnection serviceConnectionWithName:ConnectionShellName rootObject:self];
    MMLog(@"Shell connection: %@", self.shellConnection);

    setenv("TERM", "xterm-256color", NO);
    setenv("LANG", "en_US.UTF-8", NO);

    [[NSRunLoop mainRunLoop] run];
}

- (void)executeCommand:(NSString *)command;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _executeCommand:command];
    });

    return;
}

- (void)_executeCommand:(NSString *)command;
{
    NSArray *items = [command componentsSeparatedByString:@" "];
    const char *argv[[items count] + 1];
    for (NSUInteger i = 0; i < [items count]; i++) {
        argv[i] = [items[i] cStringUsingEncoding:NSUTF8StringEncoding];
    }
    argv[[items count]] = NULL;

    if ([items[0] isEqual:@"cd"]) {
        [self handleSpecialCommand:command];
        NSProxy *proxy = [[NSConnection connectionWithRegisteredName:ConnectionTerminalName host:nil] rootProxy];
        [proxy performSelector:@selector(processFinished)];

        return;
    }

    MMLog(@"Running %s", argv[0]);

    pid_t child_pid;
    child_pid = fork();
    MMLog(@"Child pid: %d", child_pid);
    if (child_pid == 0) {
        // This will run the program.

        int status = execvp(argv[0],(char* const*)argv);

        NSLog(@"Exec failed :( %d", status);

        _exit(-1);
    }

    [NSThread detachNewThreadSelector:@selector(waitForChildToFinish:) toTarget:self withObject:@((int)child_pid)];
}

- (void)waitForChildToFinish:(NSNumber *)child_pid;
{
    waitpid([child_pid intValue], NULL, 0);

    NSProxy *proxy = [[NSConnection connectionWithRegisteredName:ConnectionTerminalName host:nil] rootProxy];
    [proxy performSelector:@selector(processFinished)];
}

- (void)handleSpecialCommand:(NSString *)command;
{
    NSArray *items = [command componentsSeparatedByString:@" "];

    if ([items[0] isEqualToString:@"cd"]) {
        NSRange whitespaceChars = [command rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *newDirectory = nil;
        if ((whitespaceChars.location == NSNotFound) ||
            ((whitespaceChars.location + whitespaceChars.length) == [command length])) {
            newDirectory = NSHomeDirectory();
        } else {
            newDirectory = [command substringFromIndex:(whitespaceChars.location + whitespaceChars.length)];
        }

        chdir([newDirectory cStringUsingEncoding:NSUTF8StringEncoding]);
        MMLog(@"Changed directory to %@", newDirectory);
    }
}

@end
