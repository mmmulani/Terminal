//
//  MMAppDelegate.m
//  Terminal
//
//  Created by Mehdi Mulani on 1/29/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMAppDelegate.h"
#import "MMShared.h"
#import "MMTerminalConnection.h"

#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>

@implementation MMAppDelegate

- (IBAction)createNewTerminal:(id)sender;
{
    static NSInteger uniqueIdentifier = 0;
    uniqueIdentifier++;

    MMTerminalConnection *terminalConnection = [[MMTerminalConnection alloc] initWithIdentifier:uniqueIdentifier];
    [self.terminalConnections addObject:terminalConnection];
    [terminalConnection createTerminalWindow];
}

- (void)startProcessMonitor;
{
    // In order for the process monitor to observer processes and determine information about them, it must be run as root.
    NSString *programId = @"mmm.ProcessMonitor";
    OSStatus status;
    AuthorizationFlags authFlags = kAuthorizationFlagDefaults;
    AuthorizationRef authRef;
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, authFlags, &authRef);

    AuthorizationItem authItem = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
	AuthorizationRights authRights = { 1, &authItem };
    authFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    status = AuthorizationCopyRights(authRef, &authRights, kAuthorizationEmptyEnvironment, authFlags, NULL);
    SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)programId, authRef, NULL);
}

# pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
    self.terminalConnections = [NSMutableArray array];

    self.terminalAppConnection = [NSConnection serviceConnectionWithName:ConnectionTerminalName rootObject:self];

    self.debugWindow = [[MMDebugMessagesWindowController alloc] init];
    [self.debugWindow showWindow:nil];

    [self createNewTerminal:nil];

    [self startProcessMonitor];
}

- (void)_logMessage:(NSString *)message;
{
    [self.debugWindow addDebugMessage:message];
}

@end
