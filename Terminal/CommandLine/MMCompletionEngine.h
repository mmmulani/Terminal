//
//  MMCompletionEngine.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMCommandsTextView;
@class MMTerminalConnection;

@interface MMCompletionEngine : NSObject

@property (strong) MMCommandsTextView *commandsTextView;
@property (strong) MMTerminalConnection *terminalConnection;

// NSTextView methods
- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
- (NSRange)rangeForUserCompletion;
- (NSString *)typeableCompletionForDisplayCompletion:(NSString *)displayableCompletion;

@end
