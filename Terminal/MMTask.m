//
//  MMTask.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTask.h"
#import "MMShared.h"

@interface MMTask ()

@property unichar **ansiLines;

@end

@implementation MMTask

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.output = [[NSTextStorage alloc] init];

    self.ansiLines = malloc(sizeof(unichar *) * TERM_HEIGHT);
    for (NSUInteger i = 0; i < TERM_HEIGHT; i++) {
        // We allocate 1 extra character for the possible newline character.
        self.ansiLines[i] = malloc(sizeof(unichar) * (TERM_WIDTH + 1));
    }
    [self clearScreen];
    self.cursorPosition = MMPositionMake(1, 1);

    return self;
}

- (void)handleCommandOutput:(NSString *)output;
{
    for (NSUInteger i = 0; i < [output length]; i++) {
        if (self.cursorPosition.y > TERM_HEIGHT) {
            MMLog(@"Cursor position too low");
            break;
        }

        unichar currentChar = [output characterAtIndex:i];
        if (currentChar == '\n') {
            [self addNewline];
        } else if (currentChar == '\r') {
            [self moveToFrontOfLine];
        } else {
            [self ansiPrint:currentChar];
        }
    }

    NSAttributedString *attribData = [[NSAttributedString alloc] initWithString:output];
    [self.output appendAttributedString:attribData];
}

# pragma mark - ANSI display methods

- (void)ansiPrint:(unichar)character;
{
    // TODO: Add height checks.
    // TODO: Add checks to see if the characters before need filling.
    if (self.cursorPosition.x == TERM_WIDTH) {
        self.ansiLines[self.cursorPosition.y][0] = character;
        self.cursorPosition = MMPositionMake(2, self.cursorPosition.y + 1);
    } else {
        self.ansiLines[self.cursorPosition.y - 1][self.cursorPosition.x - 1] = character;
        self.cursorPosition = MMPositionMake(self.cursorPosition.x + 1, self.cursorPosition.y);
    }

    [self checkIfExceededLastLine];
}

- (void)addNewline;
{
    self.ansiLines[self.cursorPosition.y - 1][TERM_WIDTH] = '\n';
    self.cursorPosition = MMPositionMake(1, self.cursorPosition.y + 1);

    [self checkIfExceededLastLine];
}

- (void)moveToFrontOfLine;
{
    self.cursorPosition = MMPositionMake(1, self.cursorPosition.y);
}

- (void)clearScreen;
{
    for (NSUInteger i = 0; i < TERM_HEIGHT; i++) {
        for (NSUInteger j = 0; j < TERM_WIDTH + 1; j++) {
            self.ansiLines[i][j] = '\0';
        }
    }
}

- (void)checkIfExceededLastLine;
{
    // TODO: Could print the first line on screen for scrollback?
    if (self.cursorPosition.y > TERM_HEIGHT) {
        NSAssert(self.cursorPosition.y == (TERM_HEIGHT + 1), @"Cursor should only be one line from the bottom");

        unichar *newLastLine = self.ansiLines[0];
        for (NSUInteger i = 0; i < TERM_HEIGHT - 1; i++) {
            self.ansiLines[i] = self.ansiLines[i + 1];
        }

        self.ansiLines[TERM_HEIGHT - 1] = newLastLine;
        for (NSUInteger i = 0; i < TERM_WIDTH + 1; i++) {
            self.ansiLines[TERM_HEIGHT - 1][i] = '\0';
        }

        self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y - 1);
    }
}

- (NSAttributedString *)currentANSIDisplay;
{
    NSMutableAttributedString *display = [[NSMutableAttributedString alloc] init];
    for (NSUInteger i = 0; i < TERM_HEIGHT; i++) {
        for (NSUInteger j = 0; j < TERM_WIDTH; j++) {
            if (self.ansiLines[i][j] == '\0') {
                break;
            }

            [display appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&self.ansiLines[i][j] length:1]]];
        }
        if (self.ansiLines[i][TERM_WIDTH] == '\n') {
            [display appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }
    }

    return display;
}

@end
