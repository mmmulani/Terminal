//
//  MMTask.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MMANSIAction.h"
#import "MMTerminalProxy.h"

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

extern NSString *MMTaskDoneHandlingOutputNotification;

@interface MMTask : NSObject <MMANSIActionDelegate, NSCoding>

+ (MMTaskIdentifier)uniqueTaskIdentifier;

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

@property (weak) MMTerminalConnection *terminalConnection;

@property (getter=isShellCommand) BOOL shellCommand;
@property BOOL shellCommandSuccessful;
@property id shellCommandAttachment;

@property MMProcessStatus finishStatus;
@property NSInteger finishCode;

- (BOOL)isFinished;

- (id)initWithTerminalConnection:(MMTerminalConnection *)terminalConnection;
- (void)handleUserInput:(NSString *)input;
- (void)handleCursorKeyInput:(MMArrowKey)arrowKey;
- (void)handleCommandOutput:(NSString *)output;
- (void)processFinished:(MMProcessStatus)status data:(id)data;

- (void)resizeTerminalToColumns:(NSInteger)columns rows:(NSInteger)rows;

// In some cases, the task does not have enough output to fill a terminal screen but we should still render the full screen.
// (e.g. after we receive a clear escape sequence.)
- (BOOL)shouldDrawFullTerminalScreen;

@end
