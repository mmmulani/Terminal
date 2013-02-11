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

- (void)executeCommand:(NSString *)command;
{
    NSArray *items = [command componentsSeparatedByString:@" "];
    const char *argv[[items count] + 1];
    for (NSUInteger i = 0; i < [items count]; i++) {
        argv[i] = [items[i] cStringUsingEncoding:NSASCIIStringEncoding];
    }
    argv[[items count]] = NULL;

    int stdout_pipe[2] = { -1, -1 };
    int stdin_pipe[2] = { -1, -1 };
    int stderr_pipe[2] = { -1, -1 };
    pid_t child_pid;

    if (pipe(stdout_pipe) < 0 || pipe(stdin_pipe) < 0 || pipe(stderr_pipe) < 0) {
        NSLog(@"Creating pipes failed! :(");
        _exit(-1);
    }

    NSLog(@"stderr pipe: %d %d", stderr_pipe[0], stderr_pipe[1]);

    child_pid = fork();
    if (child_pid == 0) {
        // This will run the program.

        dup2(stdin_pipe[0], STDIN_FILENO);
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);

        int status = execvp(argv[0],(char* const*)argv);

        NSLog(@"Exec failed :( %d", status);

        _exit(-1);
    } else {
        close(stdin_pipe[1]);
        close(stdout_pipe[0]);
        close(stderr_pipe[1]);
    }

    fd_set rfds;
    while (true) {
        sleep(1);

        FD_ZERO(&rfds);

        FD_SET(stderr_pipe[0], &rfds);

        int result = select(stderr_pipe[0] + 1, &rfds, NULL, NULL, NULL);

        if (FD_ISSET(stderr_pipe[0], &rfds)) {
            NSLog(@"Checking..");

            NSMutableData *data = [NSMutableData dataWithLength:2048];
            ssize_t bytesread = read(stderr_pipe[0], [data mutableBytes], 2048);

            [data setLength:bytesread];
            NSString *readData = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            NSLog(@"Read in %@", readData);
        }
    }
}

@end
