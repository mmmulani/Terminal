//
//  MMShellMain.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMShellMain.h"
#import "MMShared.h"
#import "MMCommandGroup.h"
#import "MMShellCommands.h"
#import "MMTaskInfo.h"

@interface MMShellMain ()

@property NSMutableDictionary *childPidToTaskId;

@end

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

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.childPidToTaskId = [NSMutableDictionary dictionary];

    return self;
}

- (void)startWithTerminalIdentifier:(NSInteger)terminalIdentifier shellIdentifer:(MMShellIdentifier)shellIdentifier;
{
    self.shellConnection = [NSConnection serviceConnectionWithName:[ConnectionShellName stringByAppendingFormat:@".%ld.%ld", terminalIdentifier, shellIdentifier] rootObject:self];
    self.terminalConnection = [NSConnection connectionWithRegisteredName:[ConnectionTerminalName stringByAppendingFormat:@".%ld", terminalIdentifier] host:nil];
    self.terminalProxy = (NSProxy<MMTerminalProxy> *)[self.terminalConnection rootProxy];
    [self.terminalProxy shellStartedWithIdentifier:shellIdentifier];

    MMLog(@"Shell connection: %@", self.shellConnection);

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

- (void)setPathVariable:(NSString *)pathVariable;
{
    setenv("PATH", [pathVariable cStringUsingEncoding:NSUTF8StringEncoding], YES);
}

- (void)executeTask:(MMTaskInfo *)taskInfo;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _executeTask:taskInfo];
    });

    return;
}

- (void)_executeTask:(MMTaskInfo *)taskInfo;
{
    MMCommandGroup *commandGroup = taskInfo.commandGroups[0];
    if (commandGroup.commands.count == 1 && [MMShellCommands isShellCommand:commandGroup.commands[0]]) {
        [self handleSpecialCommand:taskInfo];
        return;
    }

    NSInteger maxArguments = 0;
    for (MMCommand *command in commandGroup.commands) {
        maxArguments = MAX(maxArguments, command.arguments.count);
    }

    const char *argv[commandGroup.commands.count][maxArguments + 1];
    int inputType[commandGroup.commands.count];
    const char *inputSource[commandGroup.commands.count];
    int outputType[commandGroup.commands.count];
    const char *outputSource[commandGroup.commands.count];
    for (NSInteger i = 0; i < commandGroup.commands.count; i++) {
        MMCommand *command = commandGroup.commands[i];
        NSArray *commandArguments = command.unescapedArguments;
        for (NSUInteger j = 0; j < commandArguments.count; j++) {
            argv[i][j] = [commandArguments[j] cStringUsingEncoding:NSUTF8StringEncoding];
        }
        argv[i][commandArguments.count] = NULL;

        inputType[i] = command.standardInputSourceType;
        if (command.standardInputSourceType == MMSourceTypeFile) {
            inputSource[i] = [command.standardInput cStringUsingEncoding:NSUTF8StringEncoding];
        }
        outputType[i] = command.standardOutputSourceType;
        if (command.standardOutputSourceType == MMSourceTypeFile) {
            outputSource[i] = [command.standardOutput cStringUsingEncoding:NSUTF8StringEncoding];
        }
    }

    int fdInput = -1;
    int fdOutput = -1;
    int pipedFdOutput = -1;
    int pipedFdInput = -1;
    pid_t child_pid;
    NSInteger totalCommands = commandGroup.commands.count;
    NSInteger currentCommand;
    // This loop sets up the file descriptors and forks the appropriate number of times so that afterwards:
    // - |currentCommand| should be executed
    for (currentCommand = 0; currentCommand < totalCommands; currentCommand++) {
        if (inputType[currentCommand] == MMSourceTypeFile) {
            fdInput = open(inputSource[currentCommand], O_RDONLY);
        } else if (inputType[currentCommand] == MMSourceTypePipe) {
            fdInput = pipedFdInput;
        }

        if (outputType[currentCommand] == MMSourceTypeFile) {
            // TODO: Do not truncate the file if it is specified as input or somehow handle the situation better.
            fdOutput = open(outputSource[currentCommand], O_CREAT | O_WRONLY | O_TRUNC, 0666);
        }

        child_pid = fork();
        if (child_pid == 0) {
            if (pipedFdOutput != -1) {
                close(pipedFdOutput);
            }

            // This will run argv[currentCommand] after exitting the loop.
            if (outputType[currentCommand] == MMSourceTypePipe) {
                int pipeFd[2];
                pipe(pipeFd);

                pipedFdOutput = pipeFd[1];
                pipedFdInput = pipeFd[0];
            }

            if (fdInput != -1) {
                dup2(fdInput, STDIN_FILENO);
                close(fdInput);
                fdInput = -1;
            }
            if (fdOutput != -1) {
                dup2(fdOutput, STDOUT_FILENO);
                close(fdOutput);
                fdOutput = -1;
            }
        } else {
            if (fdInput != -1) {
                close(fdInput);
            }
            if (fdOutput != -1) {
                close(fdOutput);
            }

            break;
        }
    }
    currentCommand--;

    if (currentCommand == -1) {
        MMLog(@"Child pid: %d", child_pid);

        if (signal(SIGINT, signalHandler) == SIG_ERR) {
            MMLog(@"Unable to attach signal handler. :(");
        }

        self.childPidToTaskId[@(child_pid)] = @(taskInfo.identifier);

        [NSThread detachNewThreadSelector:@selector(waitForChildToFinish:) toTarget:self withObject:@((int)child_pid)];

        return;
    }

    if (pipedFdOutput != -1) {
        dup2(pipedFdOutput, STDOUT_FILENO);
        close(pipedFdOutput);
    }

    int status = execvp(argv[currentCommand][0], (char * const *)argv[currentCommand]);

    NSLog(@"Exec failed :( %d %d", status, errno);
    NSLog(@"currentCommand %ld argv[0] %s", currentCommand, argv[currentCommand][0]);

    _exit(-1);
}

- (void)endShell;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        exit(0);
    });
}

- (void)waitForChildToFinish:(NSNumber *)child_pid;
{
    int status;
    waitpid([child_pid intValue], &status, 0);
    MMTaskIdentifier taskIdentifier = [self.childPidToTaskId[child_pid] integerValue];

    if (WIFEXITED(status)) {
        [self.terminalProxy taskFinished:taskIdentifier status:MMProcessStatusExit data:@(WEXITSTATUS(status))];
    } else {
        NSAssert(WIFSIGNALED(status), @"Process should only terminate by exiting or by a signal");
        [self.terminalProxy taskFinished:taskIdentifier status:MMProcessStatusSignal data:@(WTERMSIG(status))];
    }
}


void signalHandler(int signalNumber) {
    if (signalNumber == SIGINT) {
        MMLog(@"Received SIGINT, should be dispatched to child process.");
    }
}

- (void)handleSpecialCommand:(MMTaskInfo *)taskInfo;
{
    MMCommand *command = [taskInfo.commandGroups[0] commands][0];
    if ([command.arguments[0] isEqualToString:@"cd"]) {
        NSString *newDirectory = nil;
        if (command.arguments.count == 1) {
            newDirectory = @"~";
        } else {
            newDirectory = command.unescapedArguments[1];
        }

        newDirectory = [newDirectory stringByExpandingTildeInPath];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL result = [fileManager changeCurrentDirectoryPath:newDirectory];

        if (result) {
            [self informTerminalOfCurrentDirectory];
            newDirectory = [[fileManager currentDirectoryPath] stringByAbbreviatingWithTildeInPath];
        }

        [self.terminalProxy taskFinished:taskInfo.identifier shellCommand:MMShellCommandCd succesful:result attachment:newDirectory];
    }
}

- (void)informTerminalOfCurrentDirectory;
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [self.terminalProxy directoryChangedTo:[fileManager currentDirectoryPath]];
}

@end
