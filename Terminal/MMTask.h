//
//  MMTask.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MMANSIAction.h"

#define TERM_WIDTH 80
#define TERM_HEIGHT 24

typedef struct _MMPosition {
    NSInteger x;
    NSInteger y;
} MMPosition;

NS_INLINE MMPosition
MMPositionMake(NSInteger x, NSInteger y)
{
    MMPosition p; p.x = x; p.y = y; return p;
}

typedef enum {
    MMArrowKeyUp = 0,
    MMArrowKeyDown,
    MMArrowKeyRight,
    MMArrowKeyLeft,
} MMArrowKey;

@class MMTerminalConnection;

@interface MMTask : NSObject <MMANSIActionDelegate, NSCoding>

@property (strong) NSMutableString *output;
@property NSTextStorage *displayTextStorage;
@property pid_t processId;
@property (strong) NSDate *startedAt;
@property (strong) NSDate *finishedAt;
@property (strong) NSString *command;
@property BOOL hasUsedWholeScreen;

@property (readonly) NSMutableAttributedString *currentANSIDisplay;
@property MMPosition cursorPosition;
@property (readonly) NSInteger cursorPositionByCharacters;
@property BOOL originMode;

@property (weak) MMTerminalConnection *terminalConnection;

@property (getter=isShellCommand) BOOL shellCommand;
@property BOOL shellCommandSuccessful;
@property id shellCommandAttachment;

- (void)handleUserInput:(NSString *)input;
- (void)handleCursorKeyInput:(MMArrowKey)arrowKey;
- (void)handleCommandOutput:(NSString *)output withVerbosity:(BOOL)verbosity;
- (void)processFinished;

// In some cases, the task does not have enough output to fill a terminal screen but we should still render the full screen.
// (e.g. after we receive a clear escape sequence.)
- (BOOL)shouldDrawFullTerminalScreen;

@end
