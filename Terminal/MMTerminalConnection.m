//
//  MMTerminalConnection.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#include <termios.h>
#include <util.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <syslog.h>
#include "iconv.h"

#import "MMTerminalConnection.h"
#import "MMTerminalWindowController.h"
#import "MMShared.h"
#import "MMCommandLineArgumentsParser.h"
#import "MMCommandGroup.h"
#import "MMTask.h"
#import "MMShellCommands.h"

#define CTRLKEY(c)   ((c)-'A'+1)

@interface MMTerminalConnection ()

@property NSConnection *connectionToSelf;
@property NSString *directoryToStartIn;

@end

@implementation MMTerminalConnection

- (id)initWithIdentifier:(NSInteger)identifier;
{
    self = [self init];
    if (!self) {
        return nil;
    }

    self.identifier = identifier;
    
    return self;
}

- (void)createTerminalWindowWithState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;
{
    self.terminalWindow = [[MMTerminalWindowController alloc] initWithTerminalConnection:self withState:state completionHandler:completionHandler];
    [self.terminalWindow showWindow:nil];
    if (state) {
        self.directoryToStartIn = [state decodeObjectForKey:@"currentDirectory"];
        completionHandler(self.terminalWindow.window, NULL);
    }
    if (!self.directoryToStartIn) {
        self.directoryToStartIn = NSHomeDirectory();
    }

    self.connectionToSelf = [NSConnection serviceConnectionWithName:[ConnectionTerminalName stringByAppendingFormat:@".%ld", (long)self.identifier] rootObject:self];

    [NSThread detachNewThreadSelector:@selector(startShell) toTarget:self withObject:nil];
}

- (void)runCommandsForTask:(MMTask *)task;
{
    // TODO: Support multiple commands.
    NSArray *commandGroups = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:task.command];

    // TODO: Handle the case of no commands better. (Also detect it better.)
    if (commandGroups.count == 0 || [commandGroups[0] commands].count == 0) {
        [self processFinished];
        return;
    }

    if (commandGroups.count > 1) {
        MMLog(@"Discarded all commands past the first in: %@", task.command);
    }

    MMCommandGroup *commandGroup = commandGroups[0];
    task.shellCommand = [MMShellCommands isShellCommand:commandGroup.commands[0]];

    NSProxy *proxy = [[NSConnection connectionWithRegisteredName:[ConnectionShellName stringByAppendingFormat:@".%ld", (long)self.identifier] host:nil] rootProxy];
    [proxy performSelector:@selector(executeCommand:) withObject:commandGroup];
    [self.terminalWindow setRunning:YES];
}

- (void)setPathVariable:(NSString *)pathVariable;
{
    NSProxy *proxy = [[NSConnection connectionWithRegisteredName:[ConnectionShellName stringByAppendingFormat:@".%ld", (long)self.identifier] host:nil] rootProxy];
    [proxy performSelector:@selector(setPathVariable:) withObject:pathVariable];
}

- (void)startShell;
{
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

	win.ws_row = DEFAULT_TERM_HEIGHT;
	win.ws_col = DEFAULT_TERM_WIDTH;
	win.ws_xpixel = 0;
	win.ws_ypixel = 0;

    const char *args[3];
    args[0] = [[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Shell"] cStringUsingEncoding:NSUTF8StringEncoding];
    args[1] = ((NSString *)[NSString stringWithFormat:@"%ld", (long)self.identifier]).UTF8String;
    args[2] = NULL;

    char ttyname[PATH_MAX];
    pid_t pid;
    int fd;
    const char *directory = NULL;
    if (self.directoryToStartIn) {
        directory = [self.directoryToStartIn cStringUsingEncoding:NSUTF8StringEncoding];
    }
    pid = forkpty(&fd, ttyname, &term, &win);

    // From here until we start the Shell, we must make sure to not get the child process in deadlock.
    // One way to do this is to use objc_msgSend on an uncached method. Therefore, we do all object calls before the fork.

    if (pid == (pid_t)0) {
        // Running as the shell.
        // These pipes are written from the shell's point-of-view.
        // That is, the shell intends to write into the writepipe, and read from the readpipe.

        if (directory) {
            chdir(directory);
        }

        syslog(LOG_NOTICE, "Starting %s", args[0]);
        execv(args[0], args);

        syslog(LOG_NOTICE, "Reached bad part. %s", args[0]);

        exit(1);
    }

    self.fd = fd;

    NSLog(@"Started with pid %d", pid);

    NSLog(@"TTY started: %@ with fd %d", [NSString stringWithCString:ttyname encoding:NSUTF8StringEncoding], self.fd);

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
            // Mac OS X caps read() to 1024 bytes (for some reason), we expect that 4KiB is the most that will be sent in one read.
            // TODO: Handle the case where a UTF-8 character is split by the 4KiB partitioning.
            NSMutableData *data = [NSMutableData dataWithLength:1024 * 4];
            ssize_t totalBytesRead = 0;
            for (NSUInteger i = 0; i < 4; i++) {
                ssize_t bytesRead = read(self.fd, [data mutableBytes] + totalBytesRead, 1024);

                if (bytesRead < 0) {
                    if (errno != EAGAIN && errno != EINTR) {
                        NSLog(@"Serious error.");
                        return;
                    }

                    if (totalBytesRead == 1024) {
                        MMLog(@"Warning: only read 1024 bytes.");
                    }
                    bytesRead = 0;
                }

                totalBytesRead += bytesRead;

                if (bytesRead < 1024) {
                    break;
                }
            }

            if (totalBytesRead == 0) {
                int status;
                waitpid(pid, &status, WNOHANG);
                if (WIFEXITED(status) || WIFSIGNALED(status)) {
                    NSLog(@"Exited?");
                    break;
                }

                continue;
            }

            [data setLength:totalBytesRead];
            NSString *readData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!readData) {
                iconv_t cd = iconv_open("UTF-8", "UTF-8");
                int discardIlseq = 1;
                struct iconv_fallbacks fallbacks;
                fallbacks.mb_to_uc_fallback = iconvFallback;
                size_t iconvResult = iconvctl(cd, ICONV_SET_FALLBACKS, &fallbacks);
                size_t inBytesLeft = data.length;
                size_t outBytesLeft = data.length;
                char *cleanBuffer = malloc(sizeof(char) * data.length);
                char *inPtr = (char *)data.mutableBytes;
                char *outPtr = cleanBuffer;
                iconvResult = iconv(cd, &inPtr, &inBytesLeft, &outPtr, &outBytesLeft);

                NSData *cleanData = [NSData dataWithBytes:cleanBuffer length:(data.length - outBytesLeft)];
                iconv_close(cd);
                free(cleanBuffer);

                readData = [[NSString alloc] initWithData:cleanData encoding:NSUTF8StringEncoding];
            }
            [self handleOutput:readData];
        }
        
        if (FD_ISSET(self.fd, &wfds)) {
            NSLog(@"Gotta write");
        }
    }
    
    close(self.fd);
    self.fd = -1;
}

void iconvFallback(const char *inbuf, size_t inbufsize, void (*write_replacement)(const unsigned int *buf, size_t buflen, void *callback_arg), void *callback_arg, void *data) {
    unsigned int replacementChar = '?';
    write_replacement(&replacementChar, 1, callback_arg);
}

- (void)handleTerminalInput:(NSString *)input;
{
    if (self.terminalWindow.running && [input length]) {
        const char *typed = [input cStringUsingEncoding:NSUTF8StringEncoding];
        write(self.fd, typed, [input length]);
    }
}

- (void)handleOutput:(NSString *)output;
{
    [self.terminalWindow handleOutput:output];
}

- (void)end;
{
    close(self.fd);
    self.connectionToSelf.rootObject = nil;
    self.connectionToSelf = nil;
}

- (void)changeTerminalSizeToColumns:(NSInteger)columns rows:(NSInteger)rows;
{
    self.terminalHeight = rows;
    self.terminalWidth = columns;

    struct winsize newSize;
    newSize.ws_col = columns;
    newSize.ws_row = rows;
    ioctl(self.fd, TIOCSWINSZ, &newSize);
}

# pragma mark - MMTerminalProxy

- (void)processFinished;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.terminalWindow processFinished];
    });
}

- (void)directoryChangedTo:(NSString *)newPath;
{
    self.currentDirectory = newPath;
    [self.terminalWindow directoryChangedTo:newPath];
}

- (void)shellCommand:(MMShellCommand)command succesful:(BOOL)success attachment:(id)attachment;
{
    MMTask *task = [self.terminalWindow lastTask];
    task.shellCommandSuccessful = success;
    task.shellCommandAttachment = attachment;

    [self.terminalWindow shellCommandFinished];
}

@end
