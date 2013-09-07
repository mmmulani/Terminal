//
//  MMInfoPanelController.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/26/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMInfoPanelController.h"

#import "MMShared.h"

@interface MMInfoPanelController ()

@property NSString *currentPanelType;
@property BOOL windowLoaded;

@end


@implementation MMInfoPanelController

+ (MMInfoPanelController *)sharedController;
{
  static MMInfoPanelController *controller = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    controller = [[MMInfoPanelController alloc] init];
  });

  return controller;
}

- (id)init;
{
  self = [self initWithWindowNibName:@"MMInfoPanelController"];
  return self;
}

- (BOOL)shouldNeverShowPanel:(NSString *)panelType;
{
  NSDictionary *panelPreferences = [[NSUserDefaults standardUserDefaults] objectForKey:MMUserDefaultsKey(panelPreferences)];
  return panelPreferences && panelPreferences[panelType] && [panelPreferences[panelType] boolValue];
}

- (void)showPanel:(NSString *)panelType;
{
  if ([self shouldNeverShowPanel:panelType]) {
    return;
  }

  if (!self.isWindowLoaded) {
    (void)self.window;
  }

  if ([panelType isEqualToString:@"SuspendControls"]) {
    [self.titleLabel setStringValue:@"Suspend Controls"];
    [self.textLabel setStringValue:@"⌃Z — Open the command box\n⇧⌘↑ — Previous command\n⇧⌘↓ — Next command\n⌘ + drag — Resize the window without changing the terminal size"];
  } else {
    NSAssert(NO, @"Unknown panel type.");
  }

  self.currentPanelType = panelType;

  if (!self.window.isVisible) {
    NSWindow *keyWindow = [NSApp keyWindow];
    CGFloat x = keyWindow.frame.origin.x + keyWindow.frame.size.width + 20;
    CGFloat y = keyWindow.frame.origin.y;
    [self.window setFrameOrigin:NSMakePoint(x, y)];
    [self.window orderFront:nil];
  }
}

- (IBAction)neverShowAgain:(id)sender;
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *panelPreferences = [[userDefaults objectForKey:MMUserDefaultsKey(panelPreferences)] mutableCopy];
  if (!panelPreferences) {
    panelPreferences = [NSMutableDictionary dictionary];
  }

  panelPreferences[self.currentPanelType] = @(self.neverShowAgainButton.state == NSOnState);
  [userDefaults setObject:panelPreferences forKey:MMUserDefaultsKey(panelPreferences)];
  [userDefaults synchronize];
}

@end
