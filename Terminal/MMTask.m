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
@property NSString *unreadOutput;

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
    NSString *outputToHandle = self.unreadOutput ? [self.unreadOutput stringByAppendingString:output] : output;
    for (NSUInteger i = 0; i < [outputToHandle length]; i++) {
        if (self.cursorPosition.y > TERM_HEIGHT) {
            MMLog(@"Cursor position too low");
            break;
        }

        unichar currentChar = [outputToHandle characterAtIndex:i];
        if (currentChar == '\n') {
            [self addNewline];
        } else if (currentChar == '\r') {
            [self moveCursorBackward:(self.cursorPosition.x - 1)];
        } else if (currentChar == '\033') { // Escape character.
            NSUInteger firstAlphabeticIndex = i;
            NSCharacterSet *lowercaseChars = [NSCharacterSet lowercaseLetterCharacterSet];
            NSCharacterSet *uppercaseChars = [NSCharacterSet uppercaseLetterCharacterSet];
            while (firstAlphabeticIndex < [output length] &&
                   ![lowercaseChars characterIsMember:[outputToHandle characterAtIndex:firstAlphabeticIndex]] &&
                   ![uppercaseChars characterIsMember:[outputToHandle characterAtIndex:firstAlphabeticIndex]]) {
                firstAlphabeticIndex++;
            }

            // The escape sequence could be split over multiple reads.
            if (firstAlphabeticIndex == [outputToHandle length]) {
                self.unreadOutput = [outputToHandle substringFromIndex:i];
                break;
            }

            NSString *escapeSequence = [outputToHandle substringWithRange:NSMakeRange(i, firstAlphabeticIndex - i + 1)];
            [self handleEscapeSequence:escapeSequence];
            i = firstAlphabeticIndex;
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

- (void)moveCursorUp:(NSUInteger)lines;
{
    NSInteger newXPosition = self.cursorPosition.x;
    if (lines >= self.cursorPosition.y) {
        newXPosition = 1;
    }

    self.cursorPosition = MMPositionMake(newXPosition, MAX(1, self.cursorPosition.y - lines));
}

- (void)moveCursorDown:(NSUInteger)lines;
{
    for (; lines > 0; lines--) {
        self.ansiLines[self.cursorPosition.y - 1][TERM_WIDTH] = '\n';
        self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y + 1);
        [self checkIfExceededLastLine];
    }

    [self fillCurrentLineWithSpacesUpToCursor];
}

- (void)moveCursorForward:(NSUInteger)spaces;
{
    // TODO: Handle wrap around/determine if it is necessary.
    self.cursorPosition = MMPositionMake(MIN(TERM_WIDTH, self.cursorPosition.x + spaces), self.cursorPosition.y);
}

- (void)moveCursorBackward:(NSUInteger)spaces;
{
    // TODO: Handle wrap around correctly.

    self.cursorPosition = MMPositionMake(MAX(1, self.cursorPosition.x - spaces), self.cursorPosition.y);
}

- (void)fillCurrentLineWithSpacesUpToCursor;
{
    for (NSUInteger i = 0; i < self.cursorPosition.x - 1; i++) {
        if (self.ansiLines[self.cursorPosition.y - 1][i] == '\0') {
            self.ansiLines[self.cursorPosition.y - 1][i] = ' ';
        }
    }
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

- (void)handleEscapeSequence:(NSString *)escapeSequence;
{
    if ([escapeSequence characterAtIndex:1] != '[') {
        MMLog(@"Unsupported escape sequence: %@", escapeSequence);
        return;
    }

    unichar escapeCode = [escapeSequence characterAtIndex:([escapeSequence length] - 1)];
    if (escapeCode == 'A') {

    } else if (escapeCode == 'B') {

    } else if (escapeCode == 'C') {

    } else if (escapeCode == 'D') {

    } else {
        MMLog(@"Unhandled escape sequence: %@", escapeSequence);
    }
}

@end
