//
//  MMTask.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTask.h"
#import "MMShared.h"
#import "MMTerminalConnection.h"
#import "MMMoveCursor.h"
#import "MMErasingActions.h"
#import "MMLineManipulationActions.h"

@interface MMTask ()

@property NSMutableArray *ansiLines;
@property NSInteger currentRowOffset;
@property NSString *unreadOutput;
@property NSInteger cursorPositionByCharacters;
@property BOOL cursorKeyMode;
@property NSInteger scrollMarginTop;
@property NSInteger scrollMarginBottom;

@end

@implementation MMTask

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.output = [[NSTextStorage alloc] init];

    self.ansiLines = [NSMutableArray arrayWithCapacity:TERM_HEIGHT];
    for (NSInteger i = 0; i < TERM_HEIGHT; i++) {
        [self.ansiLines addObject:[NSMutableString stringWithString:[@"" stringByPaddingToLength:81 withString:@"\0" startingAtIndex:0]]];
    }
    self.currentRowOffset = 0;
    self.cursorPosition = MMPositionMake(1, 1);
    self.scrollMarginTop = 1;
    self.scrollMarginBottom = 24;
    MMANSIAction *action = [[MMClearScreen alloc] initWithArguments:@[@2]];
    action.delegate = self;
    [action do];

    return self;
}

- (void)handleUserInput:(NSString *)input;
{
    [self.terminalConnection handleTerminalInput:input];
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
            MMANSIAction *action = [[MMMoveCursorBackward alloc] initWithArguments:@[@(self.cursorPosition.x - 1)]];
            action.delegate = self;
            [action do];
        } else if (currentChar == '\b') {
            if (verbosity) {
                MMLog(@"Handling backspace.");
            }

            MMANSIAction *action = [[MMMoveCursorBackward alloc] initWithArguments:@[@1]];
            action.delegate = self;
            [action do];
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
                [self handleEscapeSequence:[outputToHandle substringWithRange:NSMakeRange(firstAlphabeticIndex, 2)]];
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

- (BOOL)shouldDrawFullTerminalScreen;
{
    // TODO: Handle the case where the command issued an escape sequence and should be treated like a "full" terminal screen.
    return self.ansiLines.count > TERM_HEIGHT ||
        (self.ansiLines.count == TERM_HEIGHT &&
         ([self.ansiLines.lastObject characterAtIndex:0] != '\0' ||
          [self.ansiLines.lastObject characterAtIndex:TERM_WIDTH] != '\0'));
}

# pragma mark - ANSI display methods

- (NSMutableString *)ansiLineAtScrollRow:(NSUInteger)row;
{
    return (NSMutableString *)self.ansiLines[self.currentRowOffset + row];
}

- (unichar)ansiCharacterAtExactRow:(NSUInteger)row column:(NSUInteger)column;
{
    return [(NSMutableString *)self.ansiLines[row] characterAtIndex:column];
}

- (unichar)ansiCharacterAtScrollRow:(NSUInteger)scrollRow column:(NSUInteger)column;
{
    return [(NSMutableString *)self.ansiLines[self.currentRowOffset + scrollRow] characterAtIndex:column];
}

- (void)setAnsiCharacterAtScrollRow:(NSUInteger)row column:(NSUInteger)column withCharacter:(unichar)character;
{
    [[self ansiLineAtScrollRow:row] replaceCharactersInRange:NSMakeRange(column, 1) withString:[NSString stringWithCharacters:&character length:1]];
}


- (void)ansiPrint:(unichar)character;
{
    [self fillCurrentScreenWithSpacesUpToCursor];

    if (self.cursorPosition.x == TERM_WIDTH + 1) {
        // If there is a newline present at the end of this line, we clear it as the text will now flow to the next line.
        [self setAnsiCharacterAtScrollRow:(self.cursorPosition.y - 1) column:(self.cursorPosition.x - 1) withCharacter:'\0'];
        self.cursorPosition = MMPositionMake(1, self.cursorPosition.y + 1);
        [self checkIfExceededLastLineAndObeyScrollMargin:YES];
    }

    [self setAnsiCharacterAtScrollRow:(self.cursorPosition.y - 1) column:(self.cursorPosition.x - 1) withCharacter:character];
    self.cursorPosition = MMPositionMake(self.cursorPosition.x + 1, self.cursorPosition.y);
}

- (void)addNewline;
{
    [self setAnsiCharacterAtScrollRow:(self.cursorPosition.y - 1) column:TERM_WIDTH withCharacter:'\n'];
    self.cursorPosition = MMPositionMake(1, self.cursorPosition.y + 1);

    [self checkIfExceededLastLineAndObeyScrollMargin:YES];
}

- (BOOL)isCursorInScrollRegion;
{
    return self.cursorPosition.y >= self.scrollMarginTop && self.cursorPosition.y <= self.scrollMarginBottom;
}

- (void)fillCurrentScreenWithSpacesUpToCursor;
{
    // Create blank lines up to the cursor.
    for (NSInteger i = self.ansiLines.count; i < self.currentRowOffset + self.cursorPosition.y; i++) {
        [self.ansiLines addObject:[NSMutableString stringWithString:[@"" stringByPaddingToLength:81 withString:@"\0" startingAtIndex:0]]];
    }

    for (NSInteger i = self.cursorPosition.y - 2; i >= 0; i--) {
        if ([self ansiCharacterAtScrollRow:i column:TERM_WIDTH] != '\0' || [self ansiCharacterAtScrollRow:i column:(TERM_WIDTH - 1)] != '\0') {
            break;
        }

        [self setAnsiCharacterAtScrollRow:i column:TERM_WIDTH withCharacter:'\n'];
    }

    for (NSInteger i = self.cursorPosition.x - 2; i >= 0; i--) {
        if ([self ansiCharacterAtScrollRow:(self.cursorPosition.y - 1) column:i] != '\0') {
            break;
        }

        [self setAnsiCharacterAtScrollRow:(self.cursorPosition.y - 1) column:i withCharacter:' '];
    }
}

- (void)index;
{
    // This corresponds to ESC D and is called IND.
    // This escape sequence moves the cursor down by one line and if it passes the bottom, scrolls down.
    NSInteger newXPosition = self.cursorPosition.x == TERM_WIDTH + 1 ? 1 : self.cursorPosition.x;
    self.cursorPosition = MMPositionMake(newXPosition, self.cursorPosition.y + 1);
    [self checkIfExceededLastLineAndObeyScrollMargin:YES];
}

- (void)reverseIndex;
{
    // This corresponds to ESC M and is called RI.
    // This escape sequence moves the cursor up by one line and if it passes the top margin, scrolls up.
    // When we scroll up, we remove a newline from the last line if it exists.
    if (self.cursorPosition.y == self.scrollMarginTop) {
        if (self.ansiLines.count >= self.currentRowOffset + self.scrollMarginBottom) {
            [self setAnsiCharacterAtScrollRow:(TERM_HEIGHT - 2) column:TERM_WIDTH withCharacter:'\0'];
            [self.ansiLines removeObjectAtIndex:(self.currentRowOffset + self.scrollMarginBottom - 1)];
        }
        NSMutableString *newLine = [NSMutableString stringWithString:[[@"" stringByPaddingToLength:80 withString:@"\0" startingAtIndex:0] stringByAppendingString:@"\n"]];
        [self.ansiLines insertObject:newLine atIndex:(self.currentRowOffset + self.scrollMarginTop - 1)];
    } else {
        self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y - 1);
    }
}

- (void)checkIfExceededLastLineAndObeyScrollMargin:(BOOL)obeyScrollMargin;
{
    if (obeyScrollMargin && (self.cursorPosition.y > self.scrollMarginBottom)) {
        NSAssert(self.cursorPosition.y == (self.scrollMarginBottom + 1), @"Cursor should only be one line below the bottom margin");

        NSMutableString *newLine = [NSMutableString stringWithString:[@"" stringByPaddingToLength:81 withString:@"\0" startingAtIndex:0]];
        if (self.scrollMarginTop > 1) {
            [self.ansiLines removeObjectAtIndex:(self.currentRowOffset + self.scrollMarginTop - 1)];
            [self.ansiLines insertObject:newLine atIndex:(self.currentRowOffset + self.scrollMarginBottom - 1)];
        } else {
            self.currentRowOffset++;
            [self.ansiLines insertObject:newLine atIndex:(self.currentRowOffset + self.scrollMarginBottom - 1)];
        }

        self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y - 1);
    } else if (self.cursorPosition.y > TERM_HEIGHT) {
        NSAssert(self.cursorPosition.y == (TERM_HEIGHT + 1), @"Cursor should only be one line from the bottom");

        self.currentRowOffset++;
        [self.ansiLines addObject:[NSMutableString stringWithString:[@"" stringByPaddingToLength:81 withString:@"\0" startingAtIndex:0]]];

        self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y - 1);
    }
}

- (void)setScrollMarginTop:(NSUInteger)top ScrollMarginBottom:(NSUInteger)bottom;
{
    // TODO: Handle [1;1r -> [1;2r and test.

    top = MIN(MAX(top, 1), TERM_HEIGHT - 1);
    bottom = MAX(MIN(bottom, TERM_HEIGHT), top + 1);

    self.scrollMarginBottom = bottom;
    self.scrollMarginTop = top;
}

- (NSMutableAttributedString *)currentANSIDisplay;
{
    NSUInteger cursorPosition = 0;

    NSMutableAttributedString *display = [[NSMutableAttributedString alloc] init];
    for (NSInteger i = 0; i < self.ansiLines.count; i++) {
        for (NSInteger j = 0; j < TERM_WIDTH; j++) {
            unichar currentChar = [self ansiCharacterAtExactRow:i column:j];
            if (currentChar == '\0') {
                break;
            }

            NSInteger adjustedYPosition = i - self.currentRowOffset;
            if (self.cursorPosition.y - 1 > adjustedYPosition ||
                (self.cursorPosition.y - 1 == adjustedYPosition && self.cursorPosition.x - 1 > j)) {
                cursorPosition++;
            }
            [display appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&currentChar length:1]]];
        }
        if ([self ansiCharacterAtExactRow:i column:TERM_WIDTH] == '\n') {
            if (self.cursorPosition.y - 1 > i - self.currentRowOffset) {
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

    MMANSIAction *action = nil;
    unichar escapeCode = [escapeSequence characterAtIndex:([escapeSequence length] - 1)];
    if ([escapeSequence characterAtIndex:1] == '[') {
        NSArray *items = [[escapeSequence substringWithRange:NSMakeRange(2, [escapeSequence length] - 3)] componentsSeparatedByString:@";"];
        if (escapeCode == 'A') {
            action = [[MMMoveCursorUp alloc] initWithArguments:items];
        } else if (escapeCode == 'B') {
            action = [[MMMoveCursorDown alloc] initWithArguments:items];
        } else if (escapeCode == 'C') {
            action = [[MMMoveCursorForward alloc] initWithArguments:items];
        } else if (escapeCode == 'D') {
            action = [[MMMoveCursorBackward alloc] initWithArguments:items];
        } else if (escapeCode == 'G') {
            action = [[MMMoveCursorPosition alloc] initWithArguments:[@[@1] arrayByAddingObjectsFromArray:items]];
        } else if (escapeCode == 'H' || escapeCode == 'f') {
            action = [[MMMoveCursorPosition alloc] initWithArguments:items];
        } else if (escapeCode == 'K') {
            action = [[MMClearUntilEndOfLine alloc] initWithArguments:items];
        } else if (escapeCode == 'J') {
            action = [[MMClearScreen alloc] initWithArguments:items];
        } else if (escapeCode == 'L') {
            action = [[MMInsertBlankLines alloc] initWithArguments:items];
        } else if (escapeCode == 'M') {
            action = [[MMDeleteLines alloc] initWithArguments:items];
        } else if (escapeCode == 'P') {
            action = [[MMDeleteCharacters alloc] initWithArguments:items];
        } else if (escapeCode == 'c') {
            [self handleUserInput:@"\033[?1;2c"];
        } else if (escapeCode == 'd') {
            // TODO: Make this determine the second argument at evaluation-time.
            id firstArg = items.count >= 1 ? items[0] : MMMoveCursorPosition.defaultArguments[0];
            action = [[MMMoveCursorPosition alloc] initWithArguments:@[firstArg, @(self.cursorPosition.x)]];
        } else if ([escapeSequence isEqualToString:@"\033[?1h"]) {
            self.cursorKeyMode = YES;
        } else if ([escapeSequence isEqualToString:@"\033[?1l"]) {
            self.cursorKeyMode = NO;
        } else if (escapeCode == 'r') {
            NSUInteger bottom = [items count] >= 2 ? [items[1] intValue] : TERM_HEIGHT;
            NSUInteger top = [items count] >= 1 ? [items[0] intValue] : 1;
            [self setScrollMarginTop:top ScrollMarginBottom:bottom];
        } else {
            MMLog(@"Unhandled escape sequence: %@", escapeSequence);
        }
    } else {
        // This covers all escape sequences that do not start with '['.
        if (escapeCode == 'D') {
            [self index];
        } else if (escapeCode == 'M') {
            [self reverseIndex];
        } else {
            MMLog(@"Unhandled early escape sequence: %@", escapeSequence);
        }
    }

    if (action) {
        action.delegate = self;
        [action do];
    }
}

# pragma mark - MMANSIActionDelegate methods

- (NSInteger)termHeight;
{
    return TERM_HEIGHT;
}

- (NSInteger)termWidth;
{
    return TERM_WIDTH;
}

- (NSInteger)cursorPositionX;
{
    return self.cursorPosition.x;
}

- (NSInteger)cursorPositionY;
{
    return self.cursorPosition.y;
}

- (void)setCursorToX:(NSInteger)x Y:(NSInteger)y;
{
    self.cursorPosition = MMPositionMake(x, y);
}

- (NSInteger)numberOfCharactersInScrollRow:(NSInteger)row;
{
    NSInteger count;
    for (count = 0; count < TERM_WIDTH; count++) {
        if ([self ansiCharacterAtScrollRow:(row - 1) column:count] == '\0') {
            break;
        }
    }

    return count;
}

- (BOOL)isScrollRowTerminatedInNewline:(NSInteger)row;
{
    return [self ansiCharacterAtScrollRow:(row - 1) column:TERM_WIDTH] == '\n';
}

- (NSInteger)numberOfRowsOnScreen;
{
    return self.ansiLines.count - self.currentRowOffset;
}

- (void)replaceCharactersAtScrollRow:(NSInteger)row scrollColumn:(NSInteger)column withString:(NSString *)replacementString;
{
    NSAssert(column + replacementString.length - 1 <= TERM_WIDTH, @"replacementString too large or incorrect column specified");
    [((NSMutableString *)self.ansiLines[self.currentRowOffset + row - 1]) replaceCharactersInRange:NSMakeRange(column - 1, replacementString.length) withString:replacementString];
}

- (void)removeCharactersInScrollRow:(NSInteger)row range:(NSRange)range shiftCharactersAfter:(BOOL)shift;
{
    NSAssert(range.location > 0, @"Range location must be provided in ANSI column form");
    if (shift) {
        NSMutableString *line = self.ansiLines[self.currentRowOffset + row - 1];
        NSInteger indexAfterRemovedRange = range.location - 1 + range.length;
        NSString *stringAfterRemovedRange = [line substringWithRange:NSMakeRange(indexAfterRemovedRange, TERM_WIDTH - indexAfterRemovedRange)];
        [line replaceCharactersInRange:NSMakeRange(range.location - 1, TERM_WIDTH - range.location + 1) withString:[@"" stringByPaddingToLength:(TERM_WIDTH - range.location + 1) withString:@"\0" startingAtIndex:0]];
        [line replaceCharactersInRange:NSMakeRange(range.location - 1, TERM_WIDTH - indexAfterRemovedRange) withString:stringAfterRemovedRange];
    } else {
        [((NSMutableString *)self.ansiLines[self.currentRowOffset + row - 1]) replaceCharactersInRange:NSMakeRange(range.location - 1, range.length) withString:[@"" stringByPaddingToLength:range.length withString:@"\0" startingAtIndex:0]];
    }
}

- (void)insertBlankLineAtScrollRow:(NSInteger)row withNewline:(BOOL)newline;
{
    NSAssert(self.numberOfRowsOnScreen < TERM_HEIGHT, @"inserting a line would cause more than termHeight lines to be displayed");
    NSString *newLineText;
    if (newline) {
        newLineText = [[@"" stringByPaddingToLength:80 withString:@"\0" startingAtIndex:0] stringByAppendingString:@"\n"];
    } else {
        newLineText = [@"" stringByPaddingToLength:81 withString:@"\0" startingAtIndex:0];
    }
    [self.ansiLines insertObject:[newLineText mutableCopy] atIndex:(self.currentRowOffset + row - 1)];
}

- (void)removeLineAtScrollRow:(NSInteger)row;
{
    [self.ansiLines removeObjectAtIndex:(self.currentRowOffset + row - 1)];
}

- (void)setScrollRow:(NSInteger)row hasNewline:(BOOL)hasNewline;
{
    [self setAnsiCharacterAtScrollRow:(row - 1) column:TERM_WIDTH withCharacter:(hasNewline ? '\n' : '\0')];
}

@end
