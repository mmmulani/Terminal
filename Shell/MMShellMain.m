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

    [[NSFileManager defaultManager] changeCurrentDirectoryPath:NSHomeDirectory()];

    NSDictionary *environmentVariables =
    @{
      @"TERM": @"xterm-256color",
      @"LANG": @"en_US.UTF-8",
      };

    for (NSString *variable in environmentVariables) {
        setenv([variable cStringUsingEncoding:NSUTF8StringEncoding], [environmentVariables[variable] cStringUsingEncoding:NSUTF8StringEncoding], NO);
    }

    [self informTerminalOfCurrentDirectory];

    [[NSRunLoop mainRunLoop] run];
}

- (void)executeCommand:(NSArray *)commandArguments;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _executeCommand:commandArguments];
    });

    return;
}

- (void)_executeCommand:(NSArray *)commandArguments;
{
    const char *argv[commandArguments.count + 1];
    for (NSUInteger i = 0; i < commandArguments.count; i++) {
        argv[i] = [commandArguments[i] cStringUsingEncoding:NSUTF8StringEncoding];
    }
    argv[commandArguments.count] = NULL;

    if ([commandArguments[0] isEqualToString:@"cd"]) {
        [self handleSpecialCommand:commandArguments];
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

    if (signal(SIGINT, signalHandler) == SIG_ERR) {
        MMLog(@"Unable to attach signal handler. :(");
    }

    [NSThread detachNewThreadSelector:@selector(waitForChildToFinish:) toTarget:self withObject:@((int)child_pid)];
}

- (void)waitForChildToFinish:(NSNumber *)child_pid;
{
    waitpid([child_pid intValue], NULL, 0);

    NSProxy *proxy = [[NSConnection connectionWithRegisteredName:ConnectionTerminalName host:nil] rootProxy];
    [proxy performSelector:@selector(processFinished)];
}

void signalHandler(int signalNumber) {
    if (signalNumber == SIGINT) {
        MMLog(@"Received SIGINT, should be dispatched to child process.");
    }
}

- (void)handleSpecialCommand:(NSArray *)commandArguments;
{
    if ([commandArguments[0] isEqualToString:@"cd"]) {
        NSString *newDirectory = nil;
        if (commandArguments.count == 1) {
            newDirectory = @"~";
        } else {
            newDirectory = commandArguments[1];
        }

        newDirectory = [newDirectory stringByExpandingTildeInPath];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager changeCurrentDirectoryPath:newDirectory];

        [self informTerminalOfCurrentDirectory];
    }
}

- (void)informTerminalOfCurrentDirectory;
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSProxy *proxy = [[NSConnection connectionWithRegisteredName:ConnectionTerminalName host:nil] rootProxy];
    [proxy performSelector:@selector(directoryChangedTo:) withObject:[fileManager currentDirectoryPath]];
}

@end
