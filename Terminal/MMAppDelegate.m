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

@interface MMAppDelegate ()

@property (strong) NSMutableArray *unassignedWindowShortcuts;

@end

@implementation MMAppDelegate

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.unassignedWindowShortcuts = [NSMutableArray arrayWithArray:@[@1, @2, @3, @4, @5, @6, @7, @8, @9, @0]];
    self.terminalConnections = [NSMutableArray array];

    return self;
}

- (IBAction)createNewTerminal:(id)sender;
{
    [self createNewTerminalWithState:nil completionHandler:nil];
}

- (void)createNewTerminalWithState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;
{
    static NSInteger uniqueIdentifier = 0;
    uniqueIdentifier++;

    MMTerminalConnection *terminalConnection = [[MMTerminalConnection alloc] initWithIdentifier:uniqueIdentifier];
    [self.terminalConnections addObject:terminalConnection];
    [terminalConnection createTerminalWindowWithState:state completionHandler:completionHandler];
}

- (NSInteger)uniqueWindowShortcut;
{
    if (self.unassignedWindowShortcuts.count == 0) {
        return -1;
    }

    NSNumber *newShortcut = self.unassignedWindowShortcuts[0];
    [self.unassignedWindowShortcuts removeObjectAtIndex:0];

    return [newShortcut integerValue];
}

- (void)resignWindowShortcut:(NSInteger)shortcut;
{
    if (shortcut != -1) {
        [self.unassignedWindowShortcuts addObject:[NSNumber numberWithInteger:shortcut]];
    }
}

- (void)updateWindowMenu;
{
    NSArray *menuItems = self.windowMenu.submenu.itemArray;
    NSInteger i;
    for (i = menuItems.count - 1; i >= 0 && [[menuItems[i] target] isKindOfClass:[NSWindow class]]; i--);
    i++;

    NSArray *windowMenuItems = [menuItems subarrayWithRange:NSMakeRange(i, menuItems.count - i)];
    for (NSMenuItem *menuItem in windowMenuItems) {
        MMTerminalWindowController *terminalWindowController = [menuItem.target windowController];
        menuItem.keyEquivalent = [NSNumber numberWithInteger:terminalWindowController.keyboardShortcut].stringValue;
        menuItem.keyEquivalentModifierMask = NSCommandKeyMask;
    }
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
    self.terminalAppConnection = [NSConnection serviceConnectionWithName:ConnectionTerminalName rootObject:self];

    if ([NSApp windows].count == 0) {
        [self createNewTerminal:nil];
    }

    self.debugWindow = [[MMDebugMessagesWindowController alloc] init];
    [self.debugWindow showWindow:nil];

#ifdef DEBUG
    // F-Script can be found here: http://www.fscript.org/download/download.htm
    int loadedFscript = [[NSBundle bundleWithPath:@"/Library/Frameworks/FScript.framework"] load];
    if (loadedFscript) {
        [[NSApp mainMenu] addItem:[[NSClassFromString(@"FScriptMenuItem") alloc] init]];
    }
#endif

//    [self startProcessMonitor];

    if (self.terminalConnections.count > 0) {
        [[(MMTerminalConnection *)self.terminalConnections[0] terminalWindow].window makeKeyWindow];
    }
}

- (void)_logMessage:(NSString *)message;
{
    [self.debugWindow addDebugMessage:message];
}

# pragma mark - NSWindowRestoration

+ (void)restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;
{
    [[NSApp delegate] createNewTerminalWithState:state completionHandler:completionHandler];
}

@end
