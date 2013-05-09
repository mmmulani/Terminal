//
//  MMTask.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@interface MMTask : NSObject

@property (strong) NSTextStorage *output;
@property pid_t processId;
@property (strong) NSDate *startedAt;
@property (strong) NSDate *finishedAt;
@property (strong) NSString *command;

@property (readonly) NSMutableAttributedString *currentANSIDisplay;
@property MMPosition cursorPosition;
@property (readonly) NSInteger cursorPositionByCharacters;

@property (strong) MMTerminalConnection *terminalConnection;

- (void)handleUserInput:(NSString *)input;
- (void)handleCursorKeyInput:(MMArrowKey)arrowKey;
- (void)handleCommandOutput:(NSString *)output withVerbosity:(BOOL)verbosity;

@end
