//
//  MMInfoPanelController.h
//  Terminal
//
//  Created by Mehdi Mulani on 6/26/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMInfoPanelController : NSWindowController

@property (strong) IBOutlet NSTextField *titleLabel;
@property (strong) IBOutlet NSTextField *textLabel;
@property (strong) IBOutlet NSButton *neverShowAgainButton;

+ (MMInfoPanelController *)sharedController;

- (void)showPanel:(NSString *)panelType;

- (IBAction)neverShowAgain:(id)sender;

@end
