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
#import "MMFirstRunWindowController.h"

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

    [[BWQuincyManager sharedQuincyManager] setSubmissionURL:@"http://crashy.mehdi.is/server/crash_v200.php"];
    [[BWQuincyManager sharedQuincyManager] setDelegate:self];
    [[BWQuincyManager sharedQuincyManager] setAutoSubmitCrashReport:YES];
}

- (void)showMainApplicationWindow;
{
    // Determine if we should show the first run window.
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL didFirstRun = [userDefaults boolForKey:@"didFirstRun"];
    if (!didFirstRun) {
        self.firstRunWindowController = [[MMFirstRunWindowController alloc] init];
        [self.firstRunWindowController showWindow:nil];

        [userDefaults setBool:YES forKey:@"didFirstRun"];
        [userDefaults synchronize];

        [self createPathVariable];

        return;
    }

    NSString *pathVariable = [userDefaults stringForKey:@"pathVariable"];
    if (pathVariable) {
        setenv("PATH", [pathVariable cStringUsingEncoding:NSUTF8StringEncoding], YES);
        for (MMTerminalConnection *terminalConnection in self.terminalConnections) {
            [terminalConnection setPathVariable:pathVariable];
        }
    }

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

- (void)createPathVariable;
{
    NSString *pathToScript = [[NSBundle mainBundle] pathForResource:@"path-script" ofType:@"sh"];
    NSMutableSet *pathComponentsSet = [NSMutableSet set];
    NSMutableArray *pathComponents = [NSMutableArray array];

    NSArray *shellPaths = @[@"/bin/zsh", @"/bin/bash"];
    for (NSString *shellPath in shellPaths) {
        NSPipe *output = [NSPipe pipe];
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = shellPath;
        task.standardOutput = output;
        task.environment = @{};

        task.arguments = @[@"-i", @"-l", pathToScript];

        @try {
            [task launch];
            [task waitUntilExit];
            NSString *pathVariable = [[NSString alloc] initWithData:[output.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding];
            NSArray *shellPathComponents = [pathVariable componentsSeparatedByString:@":"];
            for (NSString *path in shellPathComponents) {
                if (![pathComponentsSet member:path]) {
                    [pathComponentsSet addObject:path];
                    [pathComponents addObject:path];
                }
            }
        }
        @catch (NSException *exception) {
            // This throws if the shell does not exist at the path we specified.
        }
    }

    if (pathComponents.count != 0) {
        NSString *newPathVariable = [pathComponents componentsJoinedByString:@":"];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:newPathVariable forKey:@"pathVariable"];
        [userDefaults synchronize];
        setenv("PATH", [newPathVariable cStringUsingEncoding:NSUTF8StringEncoding], YES);
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
