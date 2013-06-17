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
#import "MMUtilities.h"
#import "MMShellProxy.h"
#import "MMTaskCellViewController.h"

@interface MMTerminalConnection ()

+ (NSInteger)uniqueShellIdentifier;

@property NSConnection *connectionToSelf;
@property NSString *directoryToStartIn;
@property NSMutableDictionary *tasksByFD;
@property NSMutableArray *unusedShells;
@property NSMutableArray *busyShells;
@property NSMutableDictionary *shellIdentifierToFD;
@property NSMutableDictionary *shellIdentifierToProxy;
@property NSMutableArray *shellCommandTasks;

- (MMShellIdentifier)unusedShell;
- (NSProxy<MMShellProxy> *)proxyForShellIdentifier:(MMShellIdentifier)identifier;
- (int)fdForTask:(MMTask *)task;

@end

@implementation MMTerminalConnection

+ (MMShellIdentifier)uniqueShellIdentifier;
{
    static NSInteger uniqueIdentifier = 0;
    uniqueIdentifier++;

    return uniqueIdentifier;
}

- (id)initWithIdentifier:(NSInteger)identifier;
{
    self = [self init];
    if (!self) {
        return nil;
    }

    self.terminalIdentifier = identifier;
    self.terminalHeight = DEFAULT_TERM_HEIGHT;
    self.terminalWidth = DEFAULT_TERM_WIDTH;
    self.tasksByFD = [NSMutableDictionary dictionary];
    self.unusedShells = [NSMutableArray array];
    self.busyShells = [NSMutableArray array];
    self.shellIdentifierToFD = [NSMutableDictionary dictionary];
    self.shellIdentifierToProxy = [NSMutableDictionary dictionary];
    self.shellCommandTasks = [NSMutableArray array];

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

    self.connectionToSelf = [NSConnection serviceConnectionWithName:[ConnectionTerminalName stringByAppendingFormat:@".%ld", (long)self.terminalIdentifier] rootObject:self];

    [self startShellsToRunCommands:1];
}

- (MMTask *)createAndRunTaskWithCommand:(NSString *)command taskDelegate:(id <MMTaskDelegate>)delegate;
{
    MMTask *task = [[MMTask alloc] initWithTerminalConnection:self];
    task.command = [NSString stringWithString:command];
    task.startedAt = [NSDate date];
    task.delegate = delegate;
    [delegate setTask:task];
    ((MMTaskCellViewController *)delegate).windowController = self.terminalWindow;

    NSArray *commandGroups = task.commandGroups;

    // TODO: Support multiple commands.
    // TODO: Handle the case of no commands better. (Also detect it better.)
    if (commandGroups.count == 0 || [commandGroups[0] commands].count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [task processFinished:MMProcessStatusError data:nil];
        });
        return task;
    }

    if (commandGroups.count > 1) {
        MMLog(@"Discarded all commands past the first in: %@", task.command);
    }

    if ([MMShellCommands isShellCommand:[commandGroups[0] commands][0]]) {
        for (NSProxy<MMShellProxy > *proxy in self.shellIdentifierToProxy.allValues) {
            [proxy executeTask:task.taskInfo];
        }

        [self.shellCommandTasks addObject:task];

        return task;
    }

    MMShellIdentifier shellIdentifier = self.unusedShell;
    [self.unusedShells removeObject:@(shellIdentifier)];
    [self.busyShells addObject:@(shellIdentifier)];

    if (shellIdentifier == 0) {
        return nil;
    }

    NSNumber *fd = self.shellIdentifierToFD[@(shellIdentifier)];
    self.tasksByFD[fd] = task;

    [task processStarted];
    [[self proxyForShellIdentifier:shellIdentifier] executeTask:task.taskInfo];

    return task;
}

- (void)setPathVariable:(NSString *)pathVariable;
{
    for (NSProxy<MMShellProxy> *proxy in self.shellIdentifierToProxy.allValues) {
        [proxy setPathVariable:pathVariable];
    }
}

- (void)startShellsToRunCommands:(NSInteger)numberOfCommands;
{
    if (numberOfCommands <= self.shellIdentifierToFD.count) {
        return;
    }

    NSInteger numberOfShellsToStart = numberOfCommands - self.shellIdentifierToFD.count;
    for (NSInteger i = 0; i < numberOfShellsToStart; i++) {
        [NSThread detachNewThreadSelector:@selector(startShell) toTarget:self withObject:nil];
    }
}

- (void)startShell;
{
    struct winsize win;
    memset(&win, 0, sizeof(struct winsize));
	win.ws_row = self.terminalHeight;
	win.ws_col = self.terminalWidth;
	win.ws_xpixel = 0;
	win.ws_ypixel = 0;

    NSInteger shellIdentifier = [[self class] uniqueShellIdentifier];

    struct termios terminalSettings;
    [self setUpTermIOSettings:&terminalSettings];

    const char *args[4];
    args[0] = [[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Shell"] cStringUsingEncoding:NSUTF8StringEncoding];
    args[1] = ((NSString *)[NSString stringWithFormat:@"%ld", self.terminalIdentifier]).UTF8String;
    args[2] = ((NSString *)[NSString stringWithFormat:@"%ld", shellIdentifier]).UTF8String;
    args[3] = NULL;

    char ttyname[PATH_MAX];
    pid_t pid;
    int fd;
    const char *directory = NULL;
    if (self.directoryToStartIn) {
        directory = [self.directoryToStartIn cStringUsingEncoding:NSUTF8StringEncoding];
    }
    pid = forkpty(&fd, ttyname, &terminalSettings, &win);

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
        execv(args[0], (char * const *)args);

        syslog(LOG_NOTICE, "Reached bad part. %s", args[0]);

        exit(1);
    }

    self.shellIdentifierToFD[@(shellIdentifier)] = @(fd);

    NSLog(@"Started with pid %d", pid);

    NSLog(@"TTY started: %@ with fd %d", [NSString stringWithCString:ttyname encoding:NSUTF8StringEncoding], fd);

    fd_set rfds;
    fd_set wfds;
    fd_set efds;

    while (true) {
        FD_ZERO(&rfds);
        FD_ZERO(&wfds);
        FD_ZERO(&efds);

        FD_SET(fd, &rfds);
        int result = select(fd + 1, &rfds, &wfds, &efds, nil);

        if (result == -1) {
            MMLog(@"select failed with errno: %d", errno);
        }

        if (FD_ISSET(fd, &rfds)) {
            // Mac OS X caps read() to 1024 bytes (for some reason), we expect that 4KiB is the most that will be sent in one read.
            // TODO: Handle the case where a UTF-8 character is split by the 4KiB partitioning.
            NSMutableData *data = [NSMutableData dataWithLength:1024 * 4];
            ssize_t totalBytesRead = 0;
            for (NSUInteger i = 0; i < 4; i++) {
                ssize_t bytesRead = read(fd, [data mutableBytes] + totalBytesRead, 1024);

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
            [self handleOutput:readData forFD:fd];
        }
        
        if (FD_ISSET(fd, &wfds)) {
            NSLog(@"Gotta write");
        }
    }
    
    close(fd);
}

void iconvFallback(const char *inbuf, size_t inbufsize, void (*write_replacement)(const unsigned int *buf, size_t buflen, void *callback_arg), void *callback_arg, void *data) {
    unsigned int replacementChar = '?';
    write_replacement(&replacementChar, 1, callback_arg);
}

- (void)setUpTermIOSettings:(struct termios *)termSettings;
{
    memset(termSettings, 0, sizeof(struct termios));

    termSettings->c_iflag = BRKINT | ICRNL | IUTF8;
	termSettings->c_oflag = OPOST | ONLCR;
	termSettings->c_cflag = CS8 | CREAD | HUPCL;
	termSettings->c_lflag = ECHOKE | ECHOE | ECHOK | ECHO | ECHOCTL | ISIG | ICANON | IEXTEN | PENDIN;

#define CONTROLPLUS(chr) ((chr - 'A') + 1)

	termSettings->c_cc[VEOF] = CONTROLPLUS('D');
	termSettings->c_cc[VEOL] = 0xff; // unused
	termSettings->c_cc[VEOL2] = 0xff; // unused
	termSettings->c_cc[VERASE] = 0x7f; // delete
	termSettings->c_cc[VWERASE] = CONTROLPLUS('W');
	termSettings->c_cc[VKILL] = CONTROLPLUS('U');
	termSettings->c_cc[VREPRINT] = CONTROLPLUS('R');
	termSettings->c_cc[VINTR] = CONTROLPLUS('C');
	termSettings->c_cc[VQUIT] = 0x1c; // control + backslash
	termSettings->c_cc[VSUSP] = CONTROLPLUS('Z');
	termSettings->c_cc[VDSUSP] = CONTROLPLUS('Y');
	termSettings->c_cc[VSTART] = CONTROLPLUS('Q');
	termSettings->c_cc[VSTOP] = CONTROLPLUS('S');
	termSettings->c_cc[VLNEXT] = CONTROLPLUS('V');
	termSettings->c_cc[VDISCARD] = CONTROLPLUS('O');
	termSettings->c_cc[VMIN] = 0xff; // unused
	termSettings->c_cc[VTIME] = 0xff; // unused
	termSettings->c_cc[VSTATUS] = CONTROLPLUS('N');

#undef CONTROLPLUS

	termSettings->c_ispeed = B230400;
	termSettings->c_ospeed = B230400;
}

- (void)handleTerminalInput:(NSString *)input task:(MMTask *)task;
{
    if ([input length]) {
        const char *typed = [input cStringUsingEncoding:NSUTF8StringEncoding];
        write([self fdForTask:task], typed, [input length]);
    }
}

- (void)handleOutput:(NSString *)output forFD:(int)fd;
{
    MMTask *task = self.tasksByFD[@(fd)];

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [task handleCommandOutput:output];
        }
        @catch (NSException *exception) {
            // Send the last 50KB of the output to our servers and then crash.
            NSData *dataToSend = [[task.output substringFromIndex:MAX(0, (NSInteger)task.output.length - (50 * 1024))] dataUsingEncoding:NSUTF8StringEncoding];
            NSURL *url = [NSURL URLWithString:@"http://crashy.mehdi.is/blobs/post.php"];
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            NSString *filename = [NSString stringWithFormat:@"%@_%@", infoDictionary[(NSString *)kCFBundleIdentifierKey], infoDictionary[(NSString *)kCFBundleVersionKey]];
            [MMUtilities postData:dataToSend toURL:url description:filename];
            @throw exception;
        }
    });
}

- (void)end;
{
    for (NSNumber *fd in self.shellIdentifierToFD.allValues) {
        close([fd intValue]);
    }
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

    for (NSNumber *fd in self.shellIdentifierToFD.allValues) {
        ioctl([fd intValue], TIOCSWINSZ, &newSize);
    }
}

# pragma mark - MMTerminalProxy

- (void)shellStartedWithIdentifier:(MMShellIdentifier)identifier;
{
    NSProxy *shellProxy = [[NSConnection connectionWithRegisteredName:[ConnectionShellName stringByAppendingFormat:@".%ld.%ld", self.terminalIdentifier, identifier] host:nil] rootProxy];
    self.shellIdentifierToProxy[@(identifier)] = shellProxy;
    [self.unusedShells addObject:@(identifier)];
}

- (void)taskFinished:(MMTaskIdentifier)taskIdentifier status:(MMProcessStatus)status data:(id)data;
{
    int fd = [self fdForTaskIdentifier:taskIdentifier];
    MMTask *task = self.tasksByFD[@(fd)];

    MMShellIdentifier shell = [self shellIdentifierForFD:fd];
    [self.unusedShells addObject:@(shell)];
    [self.busyShells removeObject:@(shell)];

    struct termios terminalSettings;
    [self setUpTermIOSettings:&terminalSettings];
    ioctl(fd, TIOCSETA, &terminalSettings);

    [task processFinished:status data:data];
}

- (void)directoryChangedTo:(NSString *)newPath;
{
    self.currentDirectory = newPath;
    [self.terminalWindow directoryChangedTo:newPath];
}

- (void)taskFinished:(MMTaskIdentifier)taskIdentifier shellCommand:(MMShellCommand)command succesful:(BOOL)success attachment:(id)attachment;
{
    MMTask *task;
    for (MMTask *possibleTask in self.shellCommandTasks) {
        if (possibleTask.identifier == taskIdentifier) {
            task = possibleTask;
            break;
        }
    }

    [self.shellCommandTasks removeObject:task];
    [task processFinished:success data:attachment];
}

# pragma mark - Shell identifier organization

- (int)fdForTask:(MMTask *)task;
{
    return [[self.tasksByFD allKeysForObject:task][0] intValue];
}

- (int)fdForTaskIdentifier:(MMTaskIdentifier)taskIdentifier;
{
    NSSet *tasksForFD = [self.tasksByFD keysOfEntriesPassingTest:^BOOL(NSNumber *fd, MMTask *task, BOOL *stop) {
        if (task.identifier == taskIdentifier) {
            *stop = YES;
            return YES;
        }

        return NO;
    }];

    if (tasksForFD.count == 0) {
        return 0;
    }

    return [tasksForFD.allObjects[0] intValue];
}

- (MMShellIdentifier)shellIdentifierForFD:(int)fd;
{
    return [[self.shellIdentifierToFD allKeysForObject:@(fd)][0] integerValue];
}

- (NSProxy<MMShellProxy> *)proxyForShellIdentifier:(MMShellIdentifier)identifier;
{
    return self.shellIdentifierToProxy[@(identifier)];
}

- (MMShellIdentifier)unusedShell;
{
    if (self.unusedShells.count == 0) {
        return 0;
    }

    return [self.unusedShells[0] integerValue];
}

@end
