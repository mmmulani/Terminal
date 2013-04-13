//
//  MMTask.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTask.h"
#import "MMShared.h"
#import "MMAppDelegate.h"

@interface MMTask ()

@property unichar **ansiLines;
@property NSString *unreadOutput;
@property NSUInteger cursorPositionByCharacters;
@property BOOL cursorKeyMode;

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

- (void)handleUserInput:(NSString *)input;
{
    MMAppDelegate *appDelegate = (MMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate handleTerminalInput:input];
}

- (void)handleCursorKeyInput:(MMArrowKey)arrowKey;
{
    NSString *arrowKeyString = @[@"A", @"B", @"C", @"D"][arrowKey];
    NSString *inputToSend = nil;
    if (self.cursorKeyMode) {
        inputToSend = [@"\033O" stringByAppendingString:arrowKeyString];
    } else {
        inputToSend = [@"\033[" stringByAppendingString:arrowKeyString];
    }
    [self handleUserInput:inputToSend];
}

- (void)handleCommandOutput:(NSString *)output withVerbosity:(BOOL)verbosity;
{
    [self.output appendAttributedString:[[NSAttributedString alloc] initWithString:output]];

    NSString *outputToHandle = self.unreadOutput ? [self.unreadOutput stringByAppendingString:output] : output;
    for (NSUInteger i = 0; i < [outputToHandle length]; i++) {
        if (self.cursorPosition.y > TERM_HEIGHT) {
            MMLog(@"Cursor position too low");
            break;
        }

        unichar currentChar = [outputToHandle characterAtIndex:i];
        if (currentChar == '\n') {
            if (verbosity) {
                MMLog(@"Handling newline.");
            }
            [self addNewline];
        } else if (currentChar == '\r') {
            if (verbosity) {
                MMLog(@"Handling carriage return.");
            }
            [self moveCursorBackward:(self.cursorPosition.x - 1)];
        } else if (currentChar == '\b') {
            if (verbosity) {
                MMLog(@"Handling backspace.");
            }
            [self moveCursorBackward:1];
        } else if (currentChar == '\a') { // Bell (beep).
            NSBeep();
            MMLog(@"Beeping.");
        } else if (currentChar == '\033') { // Escape character.
            NSUInteger firstAlphabeticIndex = i;
            if ([outputToHandle length] == (firstAlphabeticIndex + 1)) {
                self.unreadOutput = [outputToHandle substringFromIndex:i];
                break;
            }

            if ([outputToHandle characterAtIndex:(firstAlphabeticIndex + 1)] != '[') {
                MMLog(@"Early unhandled escape sequence: %@", [outputToHandle substringWithRange:NSMakeRange(firstAlphabeticIndex, 2)]);
                i = i + 1;
                continue;
            }

            NSCharacterSet *lowercaseChars = [NSCharacterSet lowercaseLetterCharacterSet];
            NSCharacterSet *uppercaseChars = [NSCharacterSet uppercaseLetterCharacterSet];
            while (firstAlphabeticIndex < [outputToHandle length] &&
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
            if (verbosity) {
                MMLog(@"Parsed escape sequence: %@", escapeSequence);
            }
            [self handleEscapeSequence:escapeSequence];
            i = firstAlphabeticIndex;
        } else {
            [self ansiPrint:currentChar];
            if (verbosity) {
                MMLog(@"Printed character %c", currentChar);
            }
        }
    }
}

# pragma mark - ANSI display methods

- (void)ansiPrint:(unichar)character;
{
    [self fillCurrentScreenWithSpacesUpToCursor];

    if (self.cursorPosition.x == TERM_WIDTH + 1) {
        self.cursorPosition = MMPositionMake(1, self.cursorPosition.y + 1);
        [self checkIfExceededLastLine];
    }

    self.ansiLines[self.cursorPosition.y - 1][self.cursorPosition.x - 1] = character;
    self.cursorPosition = MMPositionMake(self.cursorPosition.x + 1, self.cursorPosition.y);
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

- (void)moveCursorUp:(NSInteger)lines;
{
    lines = MAX(lines, 1);
    // Comparing it to TERM_WIDTH handles the case where the cursor is past the right margin (which occurs when we right a character at the right margin).
    NSInteger newPositionX = MIN(self.cursorPosition.x, TERM_WIDTH);
    if (lines >= self.cursorPosition.y) {
        newPositionX = 1;
    }
    NSInteger newPositionY = MAX(1, self.cursorPosition.y - lines);

    self.cursorPosition = MMPositionMake(newPositionX, newPositionY);
}

- (void)moveCursorDown:(NSInteger)lines;
{
    lines = MAX(lines, 1);

    NSInteger newPositionY = MIN(self.cursorPosition.y + lines, TERM_HEIGHT + 1);
    self.cursorPosition = MMPositionMake(self.cursorPosition.x, newPositionY);

    [self checkIfExceededLastLine];
}

- (void)moveCursorForward:(NSInteger)spaces;
{
    // Unlike the control command to move the cursor backwards, this does not have to deal with wrapping around the margin.

    spaces = MAX(spaces, 1);

    self.cursorPosition = MMPositionMake(MIN(TERM_WIDTH, self.cursorPosition.x + spaces), self.cursorPosition.y);
}

- (void)moveCursorBackward:(NSInteger)spaces;
{
    spaces = MAX(spaces, 1);

    NSInteger newPositionX = self.cursorPosition.x;
    NSInteger newPositionY = self.cursorPosition.y;
    while (spaces > 0) {
        NSInteger distanceToMove = MIN(spaces, newPositionX - 1);

        newPositionX -= distanceToMove;
        spaces -= distanceToMove;

        if (newPositionY == 1 || self.ansiLines[newPositionY - 2][TERM_WIDTH] == '\n') {
            spaces = 0;
        } else if (spaces > 0) {
            newPositionY--;
            newPositionX = TERM_WIDTH + 1;
        }
    }

    self.cursorPosition = MMPositionMake(newPositionX, newPositionY);
}

- (void)moveCursorToX:(NSUInteger)x Y:(NSUInteger)y;
{
    // Sanitize the input.
    x = MIN(MAX(x, 1), TERM_WIDTH);
    y = MIN(MAX(y, 1), TERM_HEIGHT);

    if (y <= self.cursorPosition.y) {
        self.cursorPosition = MMPositionMake(x, y);
    } else {
        // We are guaranteed that y >= 2.
        // Add newlines when necessary starting from the final row and moving up.
        for (NSUInteger row = y; row > self.cursorPosition.y; row--) {
            if (self.ansiLines[row - 1][0] != '\0') {
                continue;
            }

            self.ansiLines[row - 2][TERM_WIDTH] = '\n';
        }

        self.cursorPosition = MMPositionMake(x, y);
    }
}

- (void)deleteCharacters:(NSUInteger)numberOfCharactersToDelete;
{
    numberOfCharactersToDelete = MAX(1, numberOfCharactersToDelete);
    // Handle the case where the cursor is past the right margin.
    NSInteger adjustedXPosition = self.cursorPosition.x;//MIN(self.cursorPosition.x, TERM_WIDTH);

    NSInteger numberOfCharactersToMove = MAX(TERM_WIDTH - numberOfCharactersToDelete - (adjustedXPosition - 1), 0);
    for (NSInteger i = 0; i < numberOfCharactersToMove; i++) {
        self.ansiLines[self.cursorPosition.y - 1][adjustedXPosition - 1 + i] = self.ansiLines[self.cursorPosition.y - 1][adjustedXPosition - 1 + i + numberOfCharactersToDelete];
    }
    for (NSInteger i = adjustedXPosition + numberOfCharactersToMove - 1; i < TERM_WIDTH; i++) {
        self.ansiLines[self.cursorPosition.y - 1][i] = '\0';
    }

    if (self.cursorPosition.y < TERM_HEIGHT &&
        (self.ansiLines[self.cursorPosition.y][0] != '\0' ||
         self.ansiLines[self.cursorPosition.y][TERM_WIDTH] != '\0')) {
        self.ansiLines[self.cursorPosition.y - 1][TERM_WIDTH] = '\n';
    }
}

- (void)insertBlankLinesFromCursor:(NSInteger)numberOfLinesToInsert;
{
    // TODO: Consider implementing this as manipulating the line pointers.

    // Three step process:
    // 1. Move the lines below the cursor down such that the |numberOfLinesToInsert| lines below the cursor are repeated.
    // 2. Clear the |numberOfLinesToInsert| lines below the cursor.
    // 3. Move the cursor to the correct spot.
    numberOfLinesToInsert = MIN(MAX(1, numberOfLinesToInsert), TERM_HEIGHT - self.cursorPosition.y);

    // Step 1.
    NSInteger numberOfLinesToMove = TERM_HEIGHT - (self.cursorPosition.y - 1) - numberOfLinesToInsert;
    for (NSInteger i = numberOfLinesToMove - 1; i >= 0; i--) {
        for (NSInteger j = 0; j <= TERM_WIDTH; j++) {
            self.ansiLines[self.cursorPosition.y - 1 + numberOfLinesToInsert + i][j] = self.ansiLines[self.cursorPosition.y - 1 + i][j];
        }
    }

    // Step 2.
    BOOL fillWithNewlines = NO;
    if (self.cursorPosition.y + numberOfLinesToInsert < TERM_HEIGHT &&
        (self.ansiLines[self.cursorPosition.y - 1 + numberOfLinesToInsert][0] != '\0' ||
         self.ansiLines[self.cursorPosition.y - 1 + numberOfLinesToInsert][TERM_WIDTH] != '\0')) {
        fillWithNewlines = YES;
    }
    for (NSInteger i = 0; i < numberOfLinesToInsert; i++) {
        for (NSInteger j = 0; j < TERM_WIDTH; j++) {
            self.ansiLines[self.cursorPosition.y - 1 + i][j] = '\0';
        }
        self.ansiLines[self.cursorPosition.y - 1 + i][TERM_WIDTH] = fillWithNewlines ? '\n' : '\0';
    }

    // Step 3.
    self.cursorPosition = MMPositionMake(1, self.cursorPosition.y);
}

- (void)deleteLinesFromCursor:(NSInteger)numberOfLinesToDelete;
{
    numberOfLinesToDelete = MIN(MAX(1, numberOfLinesToDelete), TERM_HEIGHT - self.cursorPosition.y + 1);

    NSInteger numberOfLinesToMove = TERM_HEIGHT - (self.cursorPosition.y - 1) - numberOfLinesToDelete;
    for (NSInteger i = 0; i < numberOfLinesToMove; i++) {
        for (NSInteger j = 0; j <= TERM_WIDTH; j++) {
            self.ansiLines[self.cursorPosition.y - 1  + i][j] = self.ansiLines[self.cursorPosition.y - 1 + i + numberOfLinesToDelete][j];
        }
    }

    for (NSInteger i = 0; i < numberOfLinesToDelete; i++) {
        for (NSInteger j = 0; j <= TERM_WIDTH; j++) {
            self.ansiLines[self.cursorPosition.y - 1 + numberOfLinesToMove + i][j] = '\0';
        }
    }

    self.cursorPosition = MMPositionMake(1, self.cursorPosition.y);
}

- (void)fillCurrentScreenWithSpacesUpToCursor;
{
    for (NSInteger i = self.cursorPosition.x - 2; i >= 0; i--) {
        if (self.ansiLines[self.cursorPosition.y - 1][i] != '\0') {
            break;
        }

        self.ansiLines[self.cursorPosition.y - 1][i] = ' ';
    }

    for (NSInteger i = self.cursorPosition.y - 2; i >= 0; i--) {
        if (self.ansiLines[i][TERM_WIDTH] != '\0' || self.ansiLines[i][TERM_WIDTH - 1] != '\0') {
            break;
        }

        self.ansiLines[i][TERM_WIDTH] = '\n';
    }
}

- (void)clearUntilEndOfLine;
{
    for (NSUInteger i = self.cursorPosition.x - 1; i < TERM_WIDTH; i++) {
        if (self.ansiLines[self.cursorPosition.y - 1][i] == '\0') {
            break;
        }

        self.ansiLines[self.cursorPosition.y - 1][i] = '\0';
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

- (NSMutableAttributedString *)currentANSIDisplay;
{
    NSUInteger cursorPosition = 0;

    NSMutableAttributedString *display = [[NSMutableAttributedString alloc] init];
    for (NSUInteger i = 0; i < TERM_HEIGHT; i++) {
        for (NSUInteger j = 0; j < TERM_WIDTH; j++) {
            if (self.ansiLines[i][j] == '\0') {
                break;
            }

            if (self.cursorPosition.y - 1 > i ||
                (self.cursorPosition.y - 1 == i && self.cursorPosition.x - 1 > j)) {
                cursorPosition++;
            }
            [display appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&self.ansiLines[i][j] length:1]]];
        }
        if (self.ansiLines[i][TERM_WIDTH] == '\n') {
            if (self.cursorPosition.y - 1 > i) {
                cursorPosition++;
            }
            [display appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }
    }

    self.cursorPositionByCharacters = cursorPosition;

    return display;
}

- (void)handleEscapeSequence:(NSString *)escapeSequence;
{
    if ([escapeSequence characterAtIndex:1] != '[') {
        MMLog(@"Unsupported escape sequence: %@", escapeSequence);
        return;
    }

    NSArray *items = [[escapeSequence substringWithRange:NSMakeRange(2, [escapeSequence length] - 3)] componentsSeparatedByString:@";"];

    unichar escapeCode = [escapeSequence characterAtIndex:([escapeSequence length] - 1)];
    if (escapeCode == 'A') {
        [self moveCursorUp:[items[0] intValue]];
    } else if (escapeCode == 'B') {
        [self moveCursorDown:[items[0] intValue]];
    } else if (escapeCode == 'C') {
        [self moveCursorForward:[items[0] intValue]];
    } else if (escapeCode == 'D') {
        [self moveCursorBackward:[items[0] intValue]];
    } else if (escapeCode == 'G') {
        NSUInteger x = [items count] >= 1 ? [items[0] intValue] : 1;
        [self moveCursorToX:x Y:self.cursorPosition.y];
    } else if (escapeCode == 'H' || escapeCode == 'f') {
        NSUInteger x = [items count] >= 2 ? [items[1] intValue] : 1;
        NSUInteger y = [items count] >= 1 ? [items[0] intValue] : 1;
        [self moveCursorToX:x Y:y];
    } else if (escapeCode == 'K') {
        [self clearUntilEndOfLine];
    } else if (escapeCode == 'J') {
        if ([items count] && [items[0] isEqualToString:@"2"]) {
            MMPosition savedPosition = self.cursorPosition;
            self.cursorPosition = MMPositionMake(1, 1);
            [self clearScreen];
            [self moveCursorToX:savedPosition.x Y:savedPosition.y];
        } else {
            MMLog(@"Unsupported clear mode with escape sequence: %@", escapeSequence);
        }
    } else if (escapeCode == 'L') {
        [self insertBlankLinesFromCursor:[items[0] intValue]];
    } else if (escapeCode == 'M') {
        [self deleteLinesFromCursor:[items[0] intValue]];
    } else if (escapeCode == 'P') {
        [self deleteCharacters:[items[0] intValue]];
    } else if (escapeCode == 'c') {
        [self handleUserInput:@"\033[?1;2c"];
    } else if (escapeCode == 'd') {
        [self moveCursorToX:self.cursorPosition.x Y:[items[0] intValue]];
    } else if ([escapeSequence isEqualToString:@"\033[?1h"]) {
        self.cursorKeyMode = YES;
    } else if ([escapeSequence isEqualToString:@"\033[?1l"]) {
        self.cursorKeyMode = NO;
    } else {
        MMLog(@"Unhandled escape sequence: %@", escapeSequence);
    }
}

@end
