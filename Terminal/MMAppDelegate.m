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
    NSError *error = nil;
    OSStatus status;
    AuthorizationFlags authFlags = kAuthorizationFlagDefaults;
    AuthorizationRef authRef;
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, authFlags, &authRef);
    if (status != errAuthorizationSuccess) {
        NSLog(@"Error with creating authorization: %d", status);
    }

    AuthorizationItem authItem = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
	AuthorizationRights authRights = { 1, &authItem };
    authFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    status = AuthorizationCopyRights(authRef, &authRights, kAuthorizationEmptyEnvironment, authFlags, NULL);
    if (status != errAuthorizationSuccess) {
        NSLog(@"Error with copying rights: %d", status);
    }
    CFErrorRef errorRef;
    BOOL result = (BOOL)SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)programId, authRef, &errorRef);
    if (!result) {
        error = CFBridgingRelease(errorRef);
        NSLog(@"Unable to start blessed job: %@", error);
    }

    xpc_connection_t connection = xpc_connection_create_mach_service("mmm.ProcessMonitor", NULL, 0);
    if (!connection) {
        NSLog(@"Unable to create connection");
    }
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        
    });
    xpc_connection_resume(connection);
}

# pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
    self.terminalConnections = [NSMutableArray array];

    self.terminalAppConnection = [NSConnection serviceConnectionWithName:ConnectionTerminalName rootObject:self];

    self.debugWindow = [[MMDebugMessagesWindowController alloc] init];
    [self.debugWindow showWindow:nil];

    [self createNewTerminal:nil];

//    [self startProcessMonitor];
}

- (void)_logMessage:(NSString *)message;
{
    [self.debugWindow addDebugMessage:message];
}

@end
