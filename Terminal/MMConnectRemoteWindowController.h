//
//  MMConnectRemoteWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 7/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MMTextView;
@protocol MMTextViewDelegate;

@interface MMConnectRemoteWindowController : NSWindowController <MMTextViewDelegate>

@property (strong) IBOutlet MMTextView *sshTextView;

@end
