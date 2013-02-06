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

#define CTRLKEY(c)   ((c)-'A'+1)

@implementation MMAppDelegate

- (void)runCommand:(NSString *)command;
{
    [NSThread detachNewThreadSelector:@selector(executeCommand:) toTarget:self withObject:command];
    self.running = YES;
}

- (void)executeCommand:(NSString *)command;
{
    NSArray *items = [command componentsSeparatedByString:@" "];

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
        int status = execvp(argv[0],(char* const*)argv);

        NSLog(@"Exec failed :( %d", status);

        _exit(-1);
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
        NSLog(@"Select result: %d", result);

        if (FD_ISSET(self.fd, &rfds)) {
            NSMutableData *data = [NSMutableData dataWithLength:2048];
            ssize_t bytesread = read(self.fd, [data mutableBytes], 2048);

            if (bytesread == 0) {
                NSLog(@"errno %d", errno);
                continue;
            }

            if (bytesread < 0) {
                NSLog(@"Read %zd bytes with errno %d", bytesread, errno);
                continue;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [data setLength:bytesread];
                NSString *readData = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                NSAttributedString *attribData = [[NSAttributedString alloc] initWithString:readData];
                NSTextStorage *textStorage = [self.consoleText textStorage];
                [textStorage beginEditing];
                [textStorage appendAttributedString:attribData];
                [textStorage endEditing];
                [self.consoleText didChangeText];
                [self.consoleText scrollToEndOfDocument:self];
            });
        }

        if (FD_ISSET(self.fd, &wfds)) {
            NSLog(@"Gotta write");
        }
    }
}

- (void)handleTerminalInput:(NSString *)input;
{
    if (self.running && [input length]) {
        const char *typed = [input cStringUsingEncoding:NSASCIIStringEncoding];
        write(self.fd, typed, [input length]);
    }
}

# pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
    [self.consoleText setEditable:NO];
    [self.window becomeFirstResponder];
    [self runCommand:@"/bin/sh"];
}

@end
