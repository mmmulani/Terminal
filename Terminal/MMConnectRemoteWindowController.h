//
//  MMConnectRemoteWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 7/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTextView.h"
#import "MMTask.h"

@interface MMConnectRemoteWindowController : NSWindowController <MMTextViewDelegate, MMTaskDelegate>

@property (strong) IBOutlet NSTextView *sshTextView;

// For MMTaskDelegate.
@property (weak) MMTask *task;

@end
