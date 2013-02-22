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

@interface MMTask : NSObject

@property (strong) NSTextStorage *output;
@property pid_t processId;
@property (strong) NSDate *startedAt;
@property (strong) NSDate *finishedAt;
@property (strong) NSString *command;

@property (readonly) NSAttributedString *currentANSIDisplay;
@property MMPosition cursorPosition;

- (void)handleCommandOutput:(NSString *)output;

@end
