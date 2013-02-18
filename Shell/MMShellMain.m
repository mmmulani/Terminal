//
//  MMShellMain.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMShellMain.h"

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
    self.shellConnection = [NSConnection serviceConnectionWithName:@"com.mm.shell" rootObject:self];
    NSLog(@"Shell connection: %@", self.shellConnection);

    setenv("TERM", "xterm-256color", NO);

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

    NSLog(@"Running %s", argv[0]);

    pid_t child_pid;
    child_pid = fork();
    if (child_pid == 0) {
        // This will run the program.

        int status = execvp(argv[0],(char* const*)argv);

        NSLog(@"Exec failed :( %d", status);

        _exit(-1);
    }

    waitpid(child_pid, NULL, 0);

    NSProxy *proxy = [[NSConnection connectionWithRegisteredName:@"com.mm.terminal" host:nil] rootProxy];
    [proxy performSelector:@selector(processFinished)];
}

@end
