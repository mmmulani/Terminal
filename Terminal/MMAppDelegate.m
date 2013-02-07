//
//  MMAppDelegate.m
//  Terminal
//
//  Created by Mehdi Mulani on 1/29/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMAppDelegate.h"

#include <termios.h>
#include <util.h>
#include <sys/wait.h>

#define CTRLKEY(c)   ((c)-'A'+1)

@implementation MMAppDelegate

+ (NSConnection *)sharedConnection;
{
    static NSConnection *connection;
    @synchronized(self) {
        if (!connection) {
            connection = [NSConnection new];
        }
    }

    return connection;
}

- (void)runCommand:(NSString *)command;
{
    [NSThread detachNewThreadSelector:@selector(executeCommand:) toTarget:self withObject:command];
    self.running = YES;
}

- (void)executeCommand:(NSString *)command;
{
    NSArray *items = [command componentsSeparatedByString:@" "];

    NSProxy *proxy = [[[self class] sharedConnection] rootProxy];

    struct termios term;
    struct winsize win;

    memset(&term, 0, sizeof(struct termios));
    memset(&win, 0, sizeof(struct winsize));

	term.c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
	term.c_oflag = OPOST | ONLCR;
	term.c_cflag = CREAD | CS8 | HUPCL;
	term.c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;

	term.c_cc[VEOF]	  = CTRLKEY('D');
	term.c_cc[VEOL]	  = -1;
	term.c_cc[VEOL2]	  = -1;
	term.c_cc[VERASE]	  = 0x7f;	// DEL
	term.c_cc[VWERASE]   = CTRLKEY('W');
	term.c_cc[VKILL]	  = CTRLKEY('U');
	term.c_cc[VREPRINT]  = CTRLKEY('R');
	term.c_cc[VINTR]	  = CTRLKEY('C');
	term.c_cc[VQUIT]	  = 0x1c;	// Control+backslash
	term.c_cc[VSUSP]	  = CTRLKEY('Z');
	term.c_cc[VDSUSP]	  = CTRLKEY('Y');
	term.c_cc[VSTART]	  = CTRLKEY('Q');
	term.c_cc[VSTOP]	  = CTRLKEY('S');
	term.c_cc[VLNEXT]	  = -1;
	term.c_cc[VDISCARD]  = -1;
	term.c_cc[VMIN]	  = 1;
	term.c_cc[VTIME]	  = 0;
	term.c_cc[VSTATUS]   = -1;

	term.c_ispeed = B38400;
	term.c_ospeed = B38400;

	win.ws_row = 24;
	win.ws_col = 80;
	win.ws_xpixel = 0;
	win.ws_ypixel = 0;

    const char *argv[[items count] + 1];
    for (NSUInteger i = 0; i < [items count]; i++) {
        argv[i] = [items[i] cStringUsingEncoding:NSASCIIStringEncoding];
    }
    argv[[items count]] = NULL;

    char ttyname[PATH_MAX];
    pid_t pid;
    {
        int fd;
        pid = forkpty(&fd, ttyname, &term, &win);
        self.fd = fd;
    }

    if (pid == (pid_t)0) {
        // Running as the shell.
        // These pipes are written from the shell's point-of-view.
        // That is, the shell intends to write into the writepipe, and read from the readpipe.

        // TODO: Pipe stderr up from the child.
        int writepipe[2] = { -1, -1 };
        int readpipe[2] = { -1, -1 };
        pid_t child_pid;

        if (pipe(readpipe) < 0 || pipe(writepipe) < 0) {
            NSLog(@"Creating pipe failed! :(");
            _exit(-1);
        }

        NSLog(@"Writepipe: %d %d", writepipe[0], writepipe[1]);
        NSLog(@"Readpipe: %d %d", readpipe[0], readpipe[1]);

        child_pid = fork();
        if (child_pid == 0) {
            // This will run the program.
            close(writepipe[1]);
            close(readpipe[0]);

            dup2(writepipe[0], STDIN_FILENO);
            dup2(readpipe[1], STDOUT_FILENO);

            int status = execvp(argv[0],(char* const*)argv);

            NSLog(@"Exec failed :( %d", status);

            _exit(-1);
        } else {
            close(writepipe[0]);
            close(readpipe[1]);
        }

        fd_set rfds;
        while (true) {
            sleep(1);

            FD_ZERO(&rfds);

            FD_SET(readpipe[0], &rfds);

//            int result = select(readpipe[0] + 1, &rfds, NULL, NULL, NULL);

//            if (FD_ISSET(self.fd, &rfds)) {
                NSLog(@"Checking..");

                NSMutableData *data = [NSMutableData dataWithLength:2048];
                ssize_t bytesread = read(readpipe[0], [data mutableBytes], 2048);

                [data setLength:bytesread];
                NSString *readData = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                NSLog(@"Read in %@", readData);
//            }
        }
    }

    NSLog(@"Started with pid %d", pid);

    NSLog(@"TTY started: %@ with fd %d", [NSString stringWithCString:ttyname encoding:NSASCIIStringEncoding], self.fd);

    fcntl(self.fd, F_SETFL, O_NONBLOCK);

    fd_set rfds;
    fd_set wfds;
    fd_set efds;

    while (true) {
        FD_ZERO(&rfds);
        FD_ZERO(&wfds);
        FD_ZERO(&efds);

        FD_SET(self.fd, &rfds);

        int result = select(self.fd + 1, &rfds, &wfds, &efds, nil);

        if (FD_ISSET(self.fd, &rfds)) {
            NSMutableData *data = [NSMutableData dataWithLength:2048];
            ssize_t bytesread = read(self.fd, [data mutableBytes], 2048);

            if (bytesread == 0) {
                int status;
                waitpid(pid, &status, WNOHANG);
                if (WIFEXITED(status) || WIFSIGNALED(status)) {
                    break;
                }

                continue;
            }

            if (bytesread < 0) {
                NSLog(@"Read %zd bytes with errno %d", bytesread, errno);
                continue;
            }

            [data setLength:bytesread];
            NSString *readData = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            [proxy performSelector:@selector(beep:) withObject:readData];
        }

        if (FD_ISSET(self.fd, &wfds)) {
            NSLog(@"Gotta write");
        }
    }

    close(self.fd);
    self.fd = -1;
    self.running = NO;
}

- (void)handleTerminalInput:(NSString *)input;
{
    if (self.running && [input length]) {
        const char *typed = [input cStringUsingEncoding:NSASCIIStringEncoding];
        write(self.fd, typed, [input length]);
    }
}

- (void)beep:(NSString *)message;
{
    NSAttributedString *attribData = [[NSAttributedString alloc] initWithString:message];
    NSTextStorage *textStorage = [self.consoleText textStorage];
    [textStorage beginEditing];
    [textStorage appendAttributedString:attribData];
    [textStorage endEditing];
    [self.consoleText didChangeText];
    [self.consoleText scrollToEndOfDocument:self];
}

# pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
    [self.consoleText setEditable:NO];
    [self.window becomeFirstResponder];
    [self runCommand:@"/bin/pwd"];

    NSConnection *serverConnection = [[self class] sharedConnection];
    [serverConnection setRootObject:self];
    [serverConnection registerName:@"lol"];
}

@end
