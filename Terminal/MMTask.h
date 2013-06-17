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

@class MMTaskInfo;
@class MMTerminalConnection;
@protocol MMTaskDelegate;

@interface MMTask : NSObject <MMANSIActionDelegate, NSCoding>

+ (MMTaskIdentifier)uniqueTaskIdentifier;

@property (strong) NSMutableString *output;
@property NSTextStorage *displayTextStorage;
@property pid_t processId;
@property (strong) NSDate *startedAt;
@property (strong) NSDate *finishedAt;
@property BOOL hasUsedWholeScreen;

@property (readonly) NSMutableAttributedString *currentANSIDisplay;
@property MMPosition cursorPosition;
@property (readonly) NSInteger cursorPositionByCharacters;

@property (weak) MMTerminalConnection *terminalConnection;
@property (weak) id<MMTaskDelegate> delegate;

@property (nonatomic, strong) NSString *command;
@property NSArray *commandGroups;
@property (getter=isShellCommand) BOOL shellCommand;
@property BOOL shellCommandSuccessful;
@property id shellCommandAttachment;

@property (readonly) MMTaskIdentifier identifier;
@property MMProcessStatus finishStatus;
@property NSInteger finishCode;

- (BOOL)isFinished;

- (MMTaskInfo *)taskInfo;

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

@protocol MMTaskDelegate <NSObject>

- (void)taskFinished:(MMTask *)task;
- (void)taskMovedToBackground:(MMTask *)task;
- (void)taskReceivedOutput:(MMTask *)task;

@end