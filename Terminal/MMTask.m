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
#import "MMIndexActions.h"
#import "MMDisplayActions.h"
#import "MMTabAction.h"
#import "MMTerminalWindowController.h"
#import "MMCommandLineArgumentsParser.h"
#import "MMShellCommands.h"
#import "MMCommandGroup.h"
#import "MMTaskInfo.h"

@interface MMTask ()

@property NSString *unreadOutput;
@property NSInteger scrollMarginTop;
@property NSInteger scrollMarginBottom;
@property NSInteger characterOffsetToScreen;
@property NSMutableArray *characterCountsOnVisibleRows;
@property NSMutableArray *scrollRowHasNewline;
@property NSMutableDictionary *characterAttributes;
@property NSInteger removedTrailingNewlineInScrollLine;
@property NSMutableArray *scrollRowTabRanges;
@property NSInteger termHeight;
@property NSInteger termWidth;
@property NSMutableSet *ansiModes;
@property NSMutableSet *decModes;
@property NSInteger currentCharacterSetSlot;

@property MMTaskIdentifier identifier;

@end

@implementation MMTask

+ (MMTaskIdentifier)uniqueTaskIdentifier;
{
    static MMTaskIdentifier identifier = 0;
    identifier++;

    return identifier;
}

- (id)init;
{
    self = [self initWithTerminalConnection:nil];
    return self;
}

- (id)initWithTerminalConnection:(MMTerminalConnection *)terminalConnection;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.identifier = [[self class] uniqueTaskIdentifier];

    self.displayTextStorage = [NSTextStorage new];
    self.output = [NSMutableString string];
    self.terminalConnection = terminalConnection;
    self.termHeight = self.terminalConnection ? self.terminalConnection.terminalHeight : DEFAULT_TERM_HEIGHT;
    self.termWidth = self.terminalConnection ? self.terminalConnection.terminalWidth : DEFAULT_TERM_WIDTH;

    self.characterCountsOnVisibleRows = [NSMutableArray arrayWithCapacity:self.termHeight];
    self.scrollRowHasNewline = [NSMutableArray arrayWithCapacity:self.termHeight];
    self.scrollRowTabRanges = [NSMutableArray arrayWithCapacity:self.termHeight];
    for (NSInteger i = 0; i < self.termHeight; i++) {
        [self.characterCountsOnVisibleRows addObject:@0];
        [self.scrollRowHasNewline addObject:@NO];
        [self.scrollRowTabRanges addObject:[NSMutableArray array]];
    }
    self.removedTrailingNewlineInScrollLine = 0;
    self.cursorPosition = MMPositionMake(1, 1);
    self.scrollMarginTop = 1;
    self.scrollMarginBottom = self.termHeight;
    self.characterAttributes = [NSMutableDictionary dictionary];
    self.characterAttributes[NSFontAttributeName] = [NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]];
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setLineBreakMode:NSLineBreakByCharWrapping];
    paragraphStyle.tabStops = @[];
    paragraphStyle.defaultTabInterval = [@" " sizeWithAttributes:self.characterAttributes].width * 8;
    self.characterAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
    self.ansiModes = [NSMutableSet set];
    self.decModes = [NSMutableSet set];

    [self setDECPrivateMode:MMDECModeAutoWrap on:YES];

    return self;
}

- (void)handleUserInput:(NSString *)input;
{
    if (!self.isFinished) {
        [self.terminalConnection handleTerminalInput:input task:self];
    }
}

- (void)handleCursorKeyInput:(MMArrowKey)arrowKey;
{
    NSString *arrowKeyString = @[@"A", @"B", @"C", @"D"][arrowKey];
    NSString *inputToSend = nil;
    if ([self isDECPrivateModeSet:MMDECModeCursorKey]) {
        inputToSend = [@"\033O" stringByAppendingString:arrowKeyString];
    } else {
        inputToSend = [@"\033[" stringByAppendingString:arrowKeyString];
    }
    [self handleUserInput:inputToSend];
}

- (void)handleCommandOutput:(NSString *)output;
{
    [self.displayTextStorage beginEditing];

    [self readdTrailingNewlineIfNecessary];

    [self.output appendString:output];

    NSString *outputToHandle = self.unreadOutput ? [self.unreadOutput stringByAppendingString:output] : output;
    NSCharacterSet *nonPrintableCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\013\014\n\t\r\b\a\033\016\017"];
    self.unreadOutput = nil;
    for (NSUInteger i = 0; i < [outputToHandle length]; i++) {
        if (self.cursorPosition.y > self.termHeight) {
            MMLog(@"Cursor position too low");
            break;
        }
        unichar currentChar = [outputToHandle characterAtIndex:i];

        if (![nonPrintableCharacters characterIsMember:currentChar]) {
            NSInteger end = i + 1;
            for (end = i + 1; end < outputToHandle.length && ![nonPrintableCharacters characterIsMember:[outputToHandle characterAtIndex:end]]; end++);

            [self ansiPrint:[outputToHandle substringWithRange:NSMakeRange(i, end - i)]];

            i = end - 1;
            continue;
        }

        if (currentChar == '\033') { // Escape character.
            NSUInteger firstIndexAfterSequence = i;
            if ([outputToHandle length] == (firstIndexAfterSequence + 1)) {
                self.unreadOutput = [outputToHandle substringFromIndex:i];
                break;
            }

            if ([outputToHandle characterAtIndex:(firstIndexAfterSequence + 1)] != '[') {
                // This is where we gather the required characters for escape sequence which does not start with "\033[".
                // The length of these escape sequences vary, so we have to determine whether we have enough output first.
                // TODO: Handle Operating System Controls (i.e. the sequences that start with "\033]").
                NSCharacterSet *prefixesThatRequireAnExtraCharacter = [NSCharacterSet characterSetWithCharactersInString:@" #%()*+"];
                if ([prefixesThatRequireAnExtraCharacter characterIsMember:[outputToHandle characterAtIndex:(firstIndexAfterSequence + 1)]]) {
                    if ([outputToHandle length] == (firstIndexAfterSequence + 2)) {
                        self.unreadOutput = [outputToHandle substringFromIndex:i];
                        break;
                    }

                    [self handleEscapeSequence:[outputToHandle substringWithRange:NSMakeRange(firstIndexAfterSequence, 3)]];
                    i = i + 2;
                    continue;
                } else {
                    [self handleEscapeSequence:[outputToHandle substringWithRange:NSMakeRange(firstIndexAfterSequence, 2)]];
                    i = i + 1;
                    continue;
                }
            }

            NSCharacterSet *terminatingChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@`"];
            while (firstIndexAfterSequence < [outputToHandle length] &&
                   ![terminatingChars characterIsMember:[outputToHandle characterAtIndex:firstIndexAfterSequence]]) {
                firstIndexAfterSequence++;
            }

            // The escape sequence could be split over multiple reads.
            if (firstIndexAfterSequence == [outputToHandle length]) {
                self.unreadOutput = [outputToHandle substringFromIndex:i];
                break;
            }

            NSString *escapeSequence = [outputToHandle substringWithRange:NSMakeRange(i, firstIndexAfterSequence - i + 1)];
            [self handleEscapeSequence:escapeSequence];
            i = firstIndexAfterSequence;
        } else {
            [self handleNonPrintableOutput:currentChar];
        }
    }

    [self removeTrailingNewlineIfNecessary];

    [self.displayTextStorage endEditing];

    [self.delegate taskReceivedOutput:self];
}

- (void)handleNonPrintableOutput:(unichar)currentChar;
{
    MMANSIAction *action = nil;
    if (currentChar == '\n') {
        action = [MMAddNewline new];
    } else if (currentChar == '\013' || currentChar == '\014') {
        action = [[MMMoveCursorDown alloc] initWithArguments:@[@1]];
    } else if (currentChar == '\t') {
        action = [MMTabAction new];
    } else if (currentChar == '\r') {
        action = [MMCarriageReturn new];
    } else if (currentChar == '\b') {
        action = [MMBackspace new];
    } else if (currentChar == '\a') { // Bell (beep).
        action = [MMBeep new];
    } else if (currentChar == '\016') { // Shift Out.
        action = [[MMCharacterSetInvocation alloc] initWithArguments:@[@1]];
    } else if (currentChar == '\017') { // Shift In.
        action = [[MMCharacterSetInvocation alloc] initWithArguments:@[@0]];
    }
    action.delegate = self;
    [action do];
}

- (BOOL)shouldDrawFullTerminalScreen;
{
    return self.hasUsedWholeScreen || self.numberOfRowsOnScreen > self.termHeight ||
        (self.numberOfRowsOnScreen == self.termHeight &&
         ([self numberOfCharactersInScrollRow:self.termHeight] > 0 ||
          [self isScrollRowTerminatedInNewline:self.termHeight]));
}

- (void)readdTrailingNewlineIfNecessary;
{
    if (self.removedTrailingNewlineInScrollLine == 0) {
        return;
    }

    [self setScrollRow:self.removedTrailingNewlineInScrollLine hasNewline:YES];
    self.removedTrailingNewlineInScrollLine = 0;
}

- (void)removeTrailingNewlineIfNecessary;
{
    if (!self.finishedAt || self.removedTrailingNewlineInScrollLine != 0) {
        return;
    }

    if (self.displayTextStorage.length > 0 && [[self.displayTextStorage attributedSubstringFromRange:NSMakeRange(self.displayTextStorage.length - 1, 1)].string isEqualToString:@"\n"]) {
        for (NSInteger i = self.numberOfRowsOnScreen; i >= 1; i--) {
            if ([self isScrollRowTerminatedInNewline:i]) {
                self.removedTrailingNewlineInScrollLine = i;
                [self setScrollRow:i hasNewline:NO];
                break;
            }
        }
    }
}

- (void)processStarted;
{
    [self.delegate taskStarted:self];
}

- (void)processFinished:(MMProcessStatus)status data:(id)data;
{
    self.finishedAt = [NSDate date];

    if (self.isShellCommand) {
        self.shellCommandSuccessful = status;
        self.shellCommandAttachment = data;
    } else {
        self.finishStatus = status;
        self.finishCode = [data integerValue];

        [self removeTrailingNewlineIfNecessary];
    }

    [self.delegate taskFinished:self];
}

- (BOOL)isFinished;
{
    return self.finishedAt != nil;
}

# pragma mark - Setting up Task for execution

- (void)setCommand:(NSString *)command;
{
    _command = command;

    self.commandGroups = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:self.command];
    self.shellCommand = self.commandGroups.count >= 1 && [MMShellCommands isShellCommand:[(MMCommandGroup *)self.commandGroups[0] commands][0]];
}

- (MMTaskInfo *)taskInfo;
{
    MMTaskInfo *taskInfo = [MMTaskInfo new];
    taskInfo.command = self.command;
    taskInfo.commandGroups = self.commandGroups;
    taskInfo.shellCommand = self.shellCommand;
    taskInfo.identifier = self.identifier;

    return taskInfo;
}

# pragma mark - ANSI display methods

- (void)adjustNumberOfCharactersOnScrollRow:(NSInteger)row byAmount:(NSInteger)change;
{
    self.characterCountsOnVisibleRows[row - 1] = @([self.characterCountsOnVisibleRows[row - 1] integerValue] + change);
}

- (NSString *)convertStringForCurrentKeyboard:(NSString *)string;
{
    MMCharacterSet currentCharacterSet = (MMCharacterSet)[@[@(self.G0CharacterSet), @(self.G1CharacterSet), @(self.G2CharacterSet), @(self.G3CharacterSet)][self.currentCharacterSetSlot] integerValue];
    if (currentCharacterSet == MMCharacterSetUSASCII) {
        return string;
    }

    NSString *original;
    NSString *replacement;
    if (currentCharacterSet == MMCharacterSetDECLineDrawing) {
        original = @"`abcdefghijklmnopqrstuvwxyz{|}~";
        replacement = @"◆▒␉␌␍␊°±␤␋┘┐┌└┼⎺⎻─⎼⎽├┤┴┬│≤≥π≠£·";
    } else if (currentCharacterSet == MMCharacterSetUnitedKingdom) {
        original = @"#";
        replacement = @"£";
    } else if (currentCharacterSet == MMCharacterSetDutch) {
        original = @"#@[\\{|}~]";
        replacement = @"£¾ÿ½¨f¼´|";
    } else if (currentCharacterSet == MMCharacterSetFinnish) {
        original = @"[\\]^`{|}~";
        replacement = @"ÄÖÅÜéäöåü";
    } else if (currentCharacterSet == MMCharacterSetFrench) {
        original = @"#@[\\]{|}~";
        replacement = @"£à°ç§éùè¨";
    } else if (currentCharacterSet == MMCharacterSetFrenchCanadian) {
        original = @"@[\\]^`{|}~";
        replacement = @"àâçêîôéùèû";
    } else if (currentCharacterSet == MMCharacterSetGerman) {
        original = @"@[\\]{|}~";
        replacement = @"§ÄÖÜäöüß";
    } else if (currentCharacterSet == MMCharacterSetItalian) {
        original = @"#@[\\]`{|}~";
        replacement = @"£§°çéùàòèì";
    } else if (currentCharacterSet == MMCharacterSetNorwegian) {
        original = @"@[\\]^`{|}~";
        replacement = @"ÄÆØÅÜäæøåü";
    } else if (currentCharacterSet == MMCharacterSetSpanish) {
        original = @"#@[\\]{|}";
        replacement = @"£§¡Ñ¿°ñç";
    } else if (currentCharacterSet == MMCharacterSetSwedish) {
        original = @"@[\\]^`{|}~";
        replacement = @"ÉÄÖÅÜéäöåü";
    } else if (currentCharacterSet == MMCharacterSetSwiss) {
        original = @"#@[\\]^_`{|}~";
        replacement = @"ùàéçêîèôäöüû";
    }

    NSAssert(original.length == replacement.length, @"Character set original and replacement text size should be the same for %d", currentCharacterSet);

    NSMutableString *convertedString = [NSMutableString stringWithString:string];
    for (NSInteger i = 0; i < original.length; i++) {
        unichar originalChar = [original characterAtIndex:i];
        unichar replacementChar = [replacement characterAtIndex:i];

        [convertedString replaceOccurrencesOfString:[NSString stringWithCharacters:&originalChar length:1] withString:[NSString stringWithCharacters:&replacementChar length:1] options:0 range:NSMakeRange(0, convertedString.length)];
    }

    return convertedString;
}

- (void)ansiPrint:(NSString *)string;
{
    [self fillCurrentScreenWithSpacesUpToCursor];

    string = [self convertStringForCurrentKeyboard:string];

    // If we are not in autowrap mode, we only print the characters that will fit on the current line.
    // Furthermore, as per the vt100 wrapping glitch (at http://invisible-island.net/xterm/xterm.faq.html#vt100_wrapping), we only print the "head" of the content to be outputted.
    if (![self isDECPrivateModeSet:MMDECModeAutoWrap] && string.length > (self.termWidth - self.cursorPosition.x + 1)) {
        self.cursorPosition = MMPositionMake(MIN(self.termWidth, self.cursorPosition.x), self.cursorPosition.y);
        NSString *charactersToInsertFromHead = [string substringWithRange:NSMakeRange(0, self.termWidth - self.cursorPositionX + 1)];
        string = charactersToInsertFromHead;
    }

    NSInteger i = 0;
    while (i < string.length) {
        if (self.cursorPosition.x == self.termWidth + 1) {
            // If there is a newline present at the end of this line, we clear it as the text will now flow to the next line.
            [self setScrollRow:self.cursorPosition.y hasNewline:NO];
            self.cursorPosition = MMPositionMake(1, self.cursorPosition.y + 1);
            [self checkIfExceededLastLineAndObeyScrollMargin:YES];
        }

        NSInteger lengthToPrintOnLine = MIN(string.length - i, self.termWidth - self.cursorPosition.x + 1);
        [self expandTabCharactersInColumnRange:NSMakeRange(self.cursorPosition.x, lengthToPrintOnLine) inScrollRow:self.cursorPosition.y];

        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[string substringWithRange:NSMakeRange(i, lengthToPrintOnLine)] attributes:self.characterAttributes];
        NSInteger numberOfCharactersToDelete = MIN(lengthToPrintOnLine, [self numberOfCharactersInScrollRow:self.cursorPosition.y] - self.cursorPosition.x + 1);
        if (numberOfCharactersToDelete > 0) {
            [self.displayTextStorage deleteCharactersInRange:NSMakeRange(self.cursorPositionByCharacters, numberOfCharactersToDelete)];
        }
        [self.displayTextStorage insertAttributedString:attributedString atIndex:self.cursorPositionByCharacters];
        [self adjustNumberOfCharactersOnScrollRow:self.cursorPosition.y byAmount:(lengthToPrintOnLine - numberOfCharactersToDelete)];
        self.cursorPosition = MMPositionMake(self.cursorPosition.x + lengthToPrintOnLine, self.cursorPosition.y);

        i += lengthToPrintOnLine;
    }
}

- (void)fillCurrentScreenWithSpacesUpToCursor;
{
    [self createBlankLinesUpToCursor];

    for (NSInteger i = self.cursorPosition.y - 1; i > 0; i--) {
        if ([self numberOfCharactersInScrollRow:i] == self.termWidth || [self isScrollRowTerminatedInNewline:i]) {
            break;
        }

        [self setScrollRow:i hasNewline:YES];
    }

    NSInteger numberOfSpacesToInsert = MAX(self.cursorPosition.x - [self numberOfCharactersInScrollRow:self.cursorPosition.y] - 1, 0);
    if (numberOfSpacesToInsert > 0) {
        [self replaceCharactersAtScrollRow:self.cursorPosition.y scrollColumn:(self.cursorPosition.x - numberOfSpacesToInsert) withString:[@"" stringByPaddingToLength:numberOfSpacesToInsert withString:@" " startingAtIndex:0]];
    }
}

- (void)incrementRowOffset;
{
    self.hasUsedWholeScreen = self.hasUsedWholeScreen || (self.characterOffsetToScreen >= self.termHeight * self.termWidth);
    self.characterOffsetToScreen += [self numberOfDisplayableCharactersInScrollRow:1];
    if ([self isScrollRowTerminatedInNewline:1]) {
        self.characterOffsetToScreen++;
    }

    [self.characterCountsOnVisibleRows removeObjectAtIndex:0];
    [self.scrollRowHasNewline removeObjectAtIndex:0];
    [self.scrollRowTabRanges removeObjectAtIndex:0];
}

- (NSInteger)characterOffsetUpToScrollRow:(NSInteger)row;
{
    NSInteger offset = self.characterOffsetToScreen;
    for (NSInteger i = 1; i < row; i++) {
        offset += [self numberOfDisplayableCharactersInScrollRow:i];
        if ([self isScrollRowTerminatedInNewline:i]) {
            offset++;
        }
    }

    return offset;
}

- (NSInteger)characterOffsetUpToScrollRow:(NSInteger)row scrollColumn:(NSInteger)column;
{
    NSInteger offset = [self characterOffsetUpToScrollRow:row] + [self characterOffsetFromStartOfLineToScrollColumn:column inScrollRow:row];
    return offset;
}


- (NSInteger)characterOffsetFromStartOfLineToScrollColumn:(NSInteger)column inScrollRow:(NSInteger)row;
{
    NSInteger offset = MIN(column - 1, [self numberOfCharactersInScrollRow:row]);

    for (NSValue *value in self.scrollRowTabRanges[row - 1]) {
        NSRange tabRange = [value rangeValue];
        if (tabRange.location <= column) {
            offset -= MIN(tabRange.length - 1, column - tabRange.location);
        }
    }

    return offset;
}

- (void)checkIfExceededLastLineAndObeyScrollMargin:(BOOL)obeyScrollMargin;
{
    if (obeyScrollMargin && (self.cursorPosition.y == self.scrollMarginBottom + 1)) {
        if (self.scrollMarginTop > 1) {
            [self removeLineAtScrollRow:self.scrollMarginTop];
            [self insertBlankLineAtScrollRow:self.scrollMarginBottom withNewline:NO];
        } else {
            [self incrementRowOffset];
            [self insertBlankLineAtScrollRow:self.scrollMarginBottom withNewline:NO];
        }

        self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y - 1);
    } else if (self.cursorPosition.y > self.termHeight) {
        NSAssert(self.cursorPosition.y == (self.termHeight + 1), @"Cursor should only be one line from the bottom");

        [self incrementRowOffset];
        [self insertBlankLineAtScrollRow:self.termHeight withNewline:NO];

        self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y - 1);
    } else if (self.cursorPosition.y == self.numberOfRowsOnScreen + 1) {
        [self insertBlankLineAtScrollRow:(self.numberOfRowsOnScreen + 1) withNewline:NO];
    }
}

- (void)setScrollMarginTop:(NSUInteger)top ScrollMarginBottom:(NSUInteger)bottom;
{
    // TODO: Handle [1;1r -> [1;2r and test.

    top = MIN(MAX(top, 1), self.termHeight - 1);
    bottom = MAX(MIN(bottom, self.termHeight), top + 1);

    self.scrollMarginBottom = bottom;
    self.scrollMarginTop = top;
}

- (NSInteger)cursorPositionByCharacters;
{
    NSInteger cursorPosition = self.characterOffsetToScreen;
    for (NSInteger i = 1; i < MIN(self.cursorPosition.y, self.numberOfRowsOnScreen); i++) {
        cursorPosition += [self numberOfDisplayableCharactersInScrollRow:i];
        if ([self isScrollRowTerminatedInNewline:i]) {
            cursorPosition++;
        }
    }

    cursorPosition = cursorPosition + (self.numberOfRowsOnScreen >= self.cursorPosition.y ? MIN([self characterOffsetFromStartOfLineToScrollColumn:self.cursorPosition.x inScrollRow:self.cursorPosition.y], [self numberOfDisplayableCharactersInScrollRow:self.cursorPosition.y]) : 0);

    return cursorPosition;
}

- (NSMutableAttributedString *)currentANSIDisplay;
{
    return [self.displayTextStorage copy];
}

- (void)handleEscapeSequence:(NSString *)escapeSequence;
{
    NSCharacterSet *nonPrintableCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\013\014\n\t\r\b\a"];
    if ([escapeSequence rangeOfCharacterFromSet:nonPrintableCharacters].location != NSNotFound) {
        escapeSequence = [escapeSequence mutableCopy];
        for (NSInteger i = 0; i < escapeSequence.length; i++) {
            unichar currentChar = [escapeSequence characterAtIndex:i];
            if ([nonPrintableCharacters characterIsMember:currentChar]) {
                [self handleNonPrintableOutput:currentChar];
                [(NSMutableString *)escapeSequence deleteCharactersInRange:NSMakeRange(i, 1)];
                i--;
            }
        }
    }

    MMANSIAction *action = nil;
    unichar escapeCode;
    if ([escapeSequence characterAtIndex:1] == '[') {
        escapeCode = [escapeSequence characterAtIndex:([escapeSequence length] - 1)];
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
            action = [[MMMoveCursorPosition alloc] initWithArguments:[@[@(self.cursorPosition.y)] arrayByAddingObjectsFromArray:items]];
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
        } else if (escapeCode == 'h' && [escapeSequence characterAtIndex:2] == '?') {
            items = [[escapeSequence substringWithRange:NSMakeRange(3, [escapeSequence length] - 4)] componentsSeparatedByString:@";"];
            action = [[MMDECPrivateModeSet alloc] initWithArguments:items];
        } else if (escapeCode == 'l' && [escapeSequence characterAtIndex:2] == '?') {
            items = [[escapeSequence substringWithRange:NSMakeRange(3, [escapeSequence length] - 4)] componentsSeparatedByString:@";"];
            action = [[MMDECPrivateModeReset alloc] initWithArguments:items];
        } else if (escapeCode == 'h') {
            action = [[MMANSIModeSet alloc] initWithArguments:items];
        } else if (escapeCode == 'l') {
            action = [[MMANSIModeReset alloc] initWithArguments:items];
        } else if (escapeCode == 'm') {
            [self handleCharacterAttributes:items];
        } else if (escapeCode == 'r') {
            action = [[MMSetScrollMargins alloc] initWithArguments:items];
        } else {
            MMLog(@"Unhandled escape sequence: %@", escapeSequence);
        }
    } else {
        escapeCode = [escapeSequence characterAtIndex:1];
        // This covers all escape sequences that do not start with '['.
        if (escapeCode == 'c') {
            action = [MMFullReset new];
        } else if (escapeCode == 'D') {
            action = [[MMIndex alloc] init];
        } else if (escapeCode == 'E') {
            action = [MMNextLine new];
        } else if (escapeCode == 'M') {
            action = [[MMReverseIndex alloc] init];
        } else if (escapeCode == '#' && [escapeSequence characterAtIndex:2] == '8') {
            action = [MMDECAlignmentTest new];
        } else if (escapeCode == '(' || escapeCode == ')' || escapeCode == '*' || escapeCode == '+') {
            action = [[MMCharacterSetDesignation alloc] initWithArguments:@[@(escapeCode), @([escapeSequence characterAtIndex:2])]];
        } else if (escapeCode == 'n') {
            action = [[MMCharacterSetInvocation alloc] initWithArguments:@[@2]];
        } else if (escapeCode == 'o') {
            action = [[MMCharacterSetInvocation alloc] initWithArguments:@[@3]];
        } else {
            MMLog(@"Unhandled early escape sequence: %@", escapeSequence);
        }
    }

    if (action) {
        action.delegate = self;
        [action do];
    }
}

- (void)handleCharacterAttributes:(NSArray *)items;
{
    if (items.count == 0) {
        items = @[@0];
    }

    for (NSNumber *argument in items) {
        switch ([argument integerValue]) {
            case 0:
                [self.characterAttributes removeObjectForKey:NSUnderlineStyleAttributeName];
                [self.characterAttributes removeObjectForKey:NSForegroundColorAttributeName];
                [self.characterAttributes removeObjectForKey:NSBackgroundColorAttributeName];
                
                self.characterAttributes[NSFontAttributeName] = [NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]];
                break;
            case 1:
                self.characterAttributes[NSFontAttributeName] = [[NSFontManager sharedFontManager] convertFont:self.characterAttributes[NSFontAttributeName] toHaveTrait:NSBoldFontMask];
                break;
            case 4:
                self.characterAttributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
                break;
            case 22:
                self.characterAttributes[NSFontAttributeName] = [[NSFontManager sharedFontManager] convertFont:self.characterAttributes[NSFontAttributeName] toHaveTrait:NSUnboldFontMask];
                break;
            case 24:
                [self.characterAttributes removeObjectForKey:NSUnderlineStyleAttributeName];
                break;
            case 30:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor blackColor];
                break;
            case 31:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedHue:0.0 saturation:1.0 brightness:0.6 alpha:1.0];
                break;
            case 32:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedHue:(120.0 / 360.0) saturation:1.0 brightness:0.65 alpha:1.0];
                break;
            case 33:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedHue:(60.0 / 360.0) saturation:1.0 brightness:0.5 alpha:1.0];
                break;
            case 34:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedHue:(240.0 / 360.0) saturation:1.0 brightness:0.7 alpha:1.0];
                break;
            case 35:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedHue:(300.0 / 360.0) saturation:1.0 brightness:0.7 alpha:1.0];
                break;
            case 36:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedHue:(184.0 / 360.0) saturation:1.0 brightness:0.7 alpha:1.0];
                break;
            case 37:
                self.characterAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedHue:(184.0 / 360.0) saturation:0.0 brightness:0.75 alpha:1.0];
                break;
            case 40:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor blackColor];
                break;
            case 41:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor colorWithCalibratedHue:0.0 saturation:1.0 brightness:0.6 alpha:1.0];
                break;
            case 42:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor colorWithCalibratedHue:(120.0 / 360.0) saturation:1.0 brightness:0.65 alpha:1.0];
                break;
            case 43:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor colorWithCalibratedHue:(60.0 / 360.0) saturation:1.0 brightness:0.5 alpha:1.0];
                break;
            case 44:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor colorWithCalibratedHue:(240.0 / 360.0) saturation:1.0 brightness:0.7 alpha:1.0];
                break;
            case 45:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor colorWithCalibratedHue:(300.0 / 360.0) saturation:1.0 brightness:0.7 alpha:1.0];
                break;
            case 46:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor colorWithCalibratedHue:(184.0 / 360.0) saturation:1.0 brightness:0.7 alpha:1.0];
                break;
            case 47:
                self.characterAttributes[NSBackgroundColorAttributeName] = [NSColor colorWithCalibratedHue:(184.0 / 360.0) saturation:0.0 brightness:0.75 alpha:1.0];
                break;
        }
    }
}

- (void)expandAllTabCharacters;
{
    for (NSInteger i = 1; i <= self.scrollRowTabRanges.count; i++) {
        for (NSValue *value in [self.scrollRowTabRanges[i - 1] copy]) {
            NSRange tabRange = [value rangeValue];
            [self convertTabRangeToCharacters:tabRange inScrollRow:i];
        }
    }
}

- (void)expandTabCharactersInColumnRange:(NSRange)printRange inScrollRow:(NSInteger)row;
{
    for (NSValue *value in [self.scrollRowTabRanges[row - 1] copy]) {
        NSRange tabRange = [value rangeValue];
        if (NSIntersectionRange(printRange, tabRange).location != 0) {
            [self convertTabRangeToCharacters:tabRange inScrollRow:row];
            [self.scrollRowTabRanges[row - 1] removeObject:value];
        }
    }
}

- (void)expandTabCharacterAtCursorIfNecessary;
{
    if (![self isColumnWithinTab:self.cursorPosition.x inScrollRow:self.cursorPosition.y]) {
        return;
    }

    for (NSValue *value in self.scrollRowTabRanges[self.cursorPosition.y - 1]) {
        NSRange tabRange = [value rangeValue];
        if (self.cursorPosition.x >= tabRange.location && self.cursorPosition.x < (tabRange.location + tabRange.length)) {
            [self convertTabRangeToCharacters:tabRange inScrollRow:self.cursorPosition.y];
            [self.scrollRowTabRanges[self.cursorPosition.y - 1] removeObject:value];

            break;
        }
    }
}


- (void)convertTabRangeToCharacters:(NSRange)tabRange inScrollRow:(NSInteger)row;
{
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[@"" stringByPaddingToLength:tabRange.length withString:@" " startingAtIndex:0] attributes:self.characterAttributes];
    [self.displayTextStorage replaceCharactersInRange:NSMakeRange([self characterOffsetUpToScrollRow:row scrollColumn:tabRange.location], 1) withAttributedString:attributedString];
}

# pragma mark - Resize methods

- (void)resizeTerminalToColumns:(NSInteger)columns rows:(NSInteger)rows;
{
    if (self.finishedAt) {
        return;
    }

    if (columns != self.termWidth) {
        [self changeTerminalWidthTo:columns];
    }

    if (rows != self.termHeight) {
        [self changeTerminalHeightTo:rows];
    }
}

- (void)changeTerminalWidthTo:(NSInteger)newTerminalWidth;
{
    // 1. Expand all tab characters to spaces.
    // 2. Starting from the bottom, reconstruct the lines of new width.
    // 3. Ensure that we finish with |numberOfRowsOnScreen| the same as before the resize.
    // 4. Calculate a cursor position so that |cursorPositionByCharacters| is the same.
    // 5. Switch out line metadata for the old line width with the newly calculated metadata.

    // Step 1.
    [self expandAllTabCharacters];

    // Step 2.
    // For each line, we need to determine its relevant metadata.
    // That is, whether the line ends in a newline and how many characters are on the line.
    NSMutableArray *numberOfCharactersOnLine = [NSMutableArray array];
    NSMutableArray *isLineEndedByNewline = [NSMutableArray array];
    NSString *outputString = self.displayTextStorage.string;
    NSInteger currentPosition = outputString.length;
    NSInteger numberOfRowsCreated = 0;
    BOOL newlineFollows = NO;
    while (numberOfRowsCreated < self.termHeight) {
        [isLineEndedByNewline addObject:@(newlineFollows)];
        if (newlineFollows) {
            currentPosition--;
        }
        NSRange lineRange = [outputString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"] options:NSBackwardsSearch range:NSMakeRange(0, currentPosition)];

        NSInteger lengthOfLine = currentPosition - (lineRange.location == NSNotFound ? -1 : lineRange.location) - 1;
        NSInteger lengthOfSingleLine = lengthOfLine % newTerminalWidth;
        if (lengthOfLine >= newTerminalWidth && lengthOfSingleLine == 0) {
            lengthOfSingleLine = newTerminalWidth;
            newlineFollows = NO;
        }
        [numberOfCharactersOnLine addObject:@(lengthOfSingleLine)];
        numberOfRowsCreated++;

        currentPosition -= lengthOfSingleLine;

        if (currentPosition - 1 == lineRange.location) {
            newlineFollows = YES;
        }
        if (lineRange.location == NSNotFound && currentPosition == 0) {
            break;
        }
    }

    NSAssert(numberOfCharactersOnLine.count == isLineEndedByNewline.count, @"Line counts should be equal");
    // Reverse the line metadata arrays.
    for (NSInteger i = 0; i < numberOfCharactersOnLine.count / 2; i++) {
        [numberOfCharactersOnLine exchangeObjectAtIndex:i withObjectAtIndex:(numberOfCharactersOnLine.count - 1 - i)];
        [isLineEndedByNewline exchangeObjectAtIndex:i withObjectAtIndex:(isLineEndedByNewline.count - 1 - i)];
    }

    // Step 3.
    // We may have created too many lines, so we prune them as necessary.
    while (numberOfRowsCreated > self.termHeight) {
        currentPosition += [numberOfCharactersOnLine[0] integerValue] + ([isLineEndedByNewline[0] boolValue] ? 1 : 0);
        [numberOfCharactersOnLine removeObjectAtIndex:0];
        [isLineEndedByNewline removeObjectAtIndex:0];
    }

    // Step 4.
    NSInteger currentCursorPosition = self.cursorPositionByCharacters - currentPosition;
    NSInteger newPositionX = 1;
    NSInteger newPositionY = 1;
    while (currentCursorPosition > 0 && newPositionY < self.termHeight) {
        NSInteger totalCharsOnLine = [numberOfCharactersOnLine[newPositionY - 1] integerValue] + ([isLineEndedByNewline[newPositionY - 1] boolValue] ? 1 : 0);
        if (totalCharsOnLine >= currentCursorPosition && ![isLineEndedByNewline[newPositionY - 1] boolValue]) {
            break;
        }
        
        newPositionY++;
        currentCursorPosition -= totalCharsOnLine;
    }
    if ([isLineEndedByNewline[newPositionY - 1] boolValue]) {
        newPositionY++;
    }

    newPositionX = MIN(currentCursorPosition + 1, newTerminalWidth);

    // Step 5.
    self.characterOffsetToScreen = currentPosition;
    self.characterCountsOnVisibleRows = numberOfCharactersOnLine;
    self.scrollRowHasNewline = isLineEndedByNewline;
    self.scrollRowTabRanges = [NSMutableArray array];
    for (NSInteger i = 0; i < numberOfCharactersOnLine.count; i++) {
        [self.scrollRowTabRanges addObject:[NSMutableArray array]];
    }
    self.cursorPosition = MMPositionMake(newPositionX, newPositionY);
    self.termWidth = newTerminalWidth;
}

- (void)changeTerminalHeightTo:(NSInteger)newHeight;
{
    if (newHeight < self.termHeight) {
        NSInteger linesToRemove = self.termHeight - newHeight;

        for (NSInteger i = self.numberOfRowsOnScreen; i > 1 && linesToRemove > 0; i--) {
            if ([self numberOfCharactersInScrollRow:i] > 0 || [self isScrollRowTerminatedInNewline:(i - 1)]) {
                break;
            }

            [self removeLineAtScrollRow:i];
            linesToRemove--;
        }

        for (NSInteger i = 0; i < linesToRemove && self.numberOfRowsOnScreen > 1; i++) {
            [self incrementRowOffset];
        }

        self.termHeight = newHeight;
        self.cursorPosition = MMPositionMake(self.cursorPosition.x, MIN(self.termHeight, self.cursorPosition.y));
    } else {
        NSString *outputString = self.displayTextStorage.string;
        NSInteger currentPosition = self.characterOffsetToScreen;
        BOOL newlineFollows = currentPosition > 0 && [outputString characterAtIndex:(currentPosition - 1)] == '\n';
        for (NSInteger i = 0; i < newHeight - self.termHeight && currentPosition > 0; i++) {
            [self.scrollRowHasNewline insertObject:@(newlineFollows) atIndex:0];
            if (newlineFollows) {
                currentPosition--;
            }
            NSRange lineRange = [outputString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"] options:NSBackwardsSearch range:NSMakeRange(0, currentPosition)];

            NSInteger lengthOfLine = currentPosition - (lineRange.location == NSNotFound ? -1 : lineRange.location) - 1;
            NSInteger lengthOfSingleLine = lengthOfLine % self.termWidth;
            if (lengthOfLine >= self.termWidth && lengthOfSingleLine == 0) {
                lengthOfSingleLine = self.termWidth;
                newlineFollows = NO;
            }
            [self.characterCountsOnVisibleRows insertObject:@(lengthOfSingleLine) atIndex:0];
            // TODO: Determine what tab ranges are in this row.
            [self.scrollRowTabRanges insertObject:[NSMutableArray array] atIndex:0];

            self.cursorPosition = MMPositionMake(self.cursorPosition.x, self.cursorPosition.y + 1);

            currentPosition -= lengthOfSingleLine;

            if (currentPosition - 1 == lineRange.location) {
                newlineFollows = YES;
            }
            if (lineRange.location == NSNotFound && currentPosition == 0) {
                break;
            }
        }
        NSAssert(self.characterCountsOnVisibleRows.count == self.scrollRowHasNewline.count, @"Number of rows on screen should be the same");
        self.characterOffsetToScreen = currentPosition;
        self.termHeight = newHeight;
    }
}

# pragma mark - MMANSIActionDelegate methods

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
    NSAssert(x > 0 && x <= self.termWidth + 1, @"X coord should be within bounds");
    NSAssert(y > 0 && y <= self.termWidth, @"Y coord should be within bounds");
    self.cursorPosition = MMPositionMake(x, y);
}

- (NSInteger)numberOfCharactersInScrollRow:(NSInteger)row;
{
    return [self.characterCountsOnVisibleRows[row - 1] integerValue];
}

- (NSInteger)numberOfDisplayableCharactersInScrollRow:(NSInteger)row;
{
    NSInteger count = [self numberOfCharactersInScrollRow:row];
    for (id value in self.scrollRowTabRanges[row - 1]) {
        NSRange tabRange = [value rangeValue];
        count = count - tabRange.length + 1;
    }

    return count;
}

- (BOOL)isScrollRowTerminatedInNewline:(NSInteger)row;
{
    return [self.scrollRowHasNewline[row - 1] boolValue];
}

- (BOOL)isCursorInScrollRegion;
{
    return self.cursorPosition.y >= self.scrollMarginTop && self.cursorPosition.y <= self.scrollMarginBottom;
}

- (BOOL)isColumnWithinTab:(NSInteger)column inScrollRow:(NSInteger)row;
{
    for (id value in self.scrollRowTabRanges[row - 1]) {
        NSRange tabRange = [value rangeValue];
        if (column >= tabRange.location && column < (tabRange.location + tabRange.length)) {
            return YES;
        }
    }

    return NO;
}

- (NSInteger)numberOfRowsOnScreen;
{
    return self.characterCountsOnVisibleRows.count;
}

- (void)replaceCharactersAtScrollRow:(NSInteger)row scrollColumn:(NSInteger)column withString:(NSString *)replacementString;
{
    NSAssert(column + replacementString.length - 1 <= self.termWidth, @"replacementString too large or incorrect column specified");
    [self expandTabCharacterAtCursorIfNecessary];

    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:replacementString attributes:self.characterAttributes];
    NSInteger enlargementSize = MAX(0, (column + ((NSInteger)replacementString.length) - 1) - [self numberOfCharactersInScrollRow:row]);
    [self adjustNumberOfCharactersOnScrollRow:row byAmount:enlargementSize];
    [self.displayTextStorage replaceCharactersInRange:NSMakeRange([self characterOffsetUpToScrollRow:row scrollColumn:column], replacementString.length - enlargementSize) withAttributedString:attributedString];
}

- (void)createBlankLinesUpToCursor;
{
    for (NSInteger i = self.numberOfRowsOnScreen; i < self.cursorPosition.y; i++) {
        [self insertBlankLineAtScrollRow:(self.numberOfRowsOnScreen + 1) withNewline:NO];
    }
}

- (void)removeCharactersInScrollRow:(NSInteger)row range:(NSRange)range shiftCharactersAfter:(BOOL)shift;
{
    NSAssert(range.location > 0, @"Range location must be provided in ANSI column form");
    if (range.location > [self numberOfCharactersInScrollRow:row]) {
        return;
    }

    [self expandTabCharactersInColumnRange:range inScrollRow:row];

    NSInteger numberOfCharactersBeingRemoved = MIN([self numberOfCharactersInScrollRow:row], range.location + range.length - 1) - range.location + 1;
    [self.displayTextStorage deleteCharactersInRange:NSMakeRange([self characterOffsetUpToScrollRow:row scrollColumn:range.location], numberOfCharactersBeingRemoved)];
    [self adjustNumberOfCharactersOnScrollRow:row byAmount:(-numberOfCharactersBeingRemoved)];
}

- (void)insertBlankLineAtScrollRow:(NSInteger)row withNewline:(BOOL)newline;
{
    NSAssert(self.numberOfRowsOnScreen < self.termHeight, @"inserting a line would cause more than termHeight lines to be displayed");
    [self.characterCountsOnVisibleRows insertObject:@0 atIndex:(row - 1)];
    [self.scrollRowHasNewline insertObject:@NO atIndex:(row - 1)];
    [self.scrollRowTabRanges insertObject:[NSMutableArray array] atIndex:(row - 1)];
    [self setScrollRow:row hasNewline:newline];
}

- (void)removeLineAtScrollRow:(NSInteger)row;
{
    NSInteger lengthIncludingNewline = ([self isScrollRowTerminatedInNewline:row] ? 1 : 0) + [self numberOfDisplayableCharactersInScrollRow:row];
    [self.displayTextStorage deleteCharactersInRange:NSMakeRange([self characterOffsetUpToScrollRow:row], lengthIncludingNewline)];
    [self.characterCountsOnVisibleRows removeObjectAtIndex:(row - 1)];
    [self.scrollRowHasNewline removeObjectAtIndex:(row - 1)];
    [self.scrollRowTabRanges removeObjectAtIndex:(row - 1)];
}

- (void)setScrollRow:(NSInteger)row hasNewline:(BOOL)hasNewline;
{
    if ([self isScrollRowTerminatedInNewline:row] == hasNewline) {
        return;
    }

    if (hasNewline) {
        [self.displayTextStorage insertAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:self.characterAttributes] atIndex:[self characterOffsetUpToScrollRow:(row + 1)]];
    } else {
        [self.displayTextStorage deleteCharactersInRange:NSMakeRange([self characterOffsetUpToScrollRow:(row + 1)] - 1, 1)];
    }
    [self.scrollRowHasNewline setObject:@(hasNewline) atIndexedSubscript:(row - 1)];
}

- (void)addTab:(NSRange)tabRange onScrollRow:(NSInteger)row;
{
    [self fillCurrentScreenWithSpacesUpToCursor];

    for (NSValue *value in self.scrollRowTabRanges[row - 1]) {
        NSRange presentTabRange = [value rangeValue];
        NSAssert(NSIntersectionRange(tabRange, presentTabRange).location == 0, @"Cannot insert a tab where one already exists");
    }

    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:@"\t" attributes:self.characterAttributes];
    [self.displayTextStorage insertAttributedString:attributedString atIndex:[self characterOffsetUpToScrollRow:row scrollColumn:tabRange.location]];
    [self adjustNumberOfCharactersOnScrollRow:row byAmount:tabRange.length];
    [self.scrollRowTabRanges[row - 1] addObject:[NSValue valueWithRange:tabRange]];
}

- (void)setANSIMode:(MMANSIMode)ansiMode on:(BOOL)on;
{
    if (on) {
        [self.ansiModes addObject:@(ansiMode)];
    } else {
        [self.ansiModes removeObject:@(ansiMode)];
    }
}

- (BOOL)isANSIModeSet:(MMANSIMode)ansiMode;
{
    return [self.ansiModes containsObject:@(ansiMode)];
}

- (void)setDECPrivateMode:(MMDECMode)decPrivateMode on:(BOOL)on;
{
    if (on) {
        [self.decModes addObject:@(decPrivateMode)];
    } else {
        [self.decModes removeObject:@(decPrivateMode)];
    }
}

- (BOOL)isDECPrivateModeSet:(MMDECMode)decPrivateMode;
{
    return [self.decModes containsObject:@(decPrivateMode)];
}

- (void)tryToResizeTerminalForColumns:(NSInteger)columns rows:(NSInteger)rows;
{
    // When we receive this instruction, we are handling output and so we have called |beginEditing| on our text storage.
    // Resizing the window will cause the window to layout and for this, we cannot be editting the text storage.
    // Thus, we have to manually end and resume editting.
    [self.displayTextStorage endEditing];

    [self.terminalConnection.terminalWindow resizeWindowForTerminalScreenSizeOfColumns:columns rows:rows];

    [self.displayTextStorage beginEditing];
}

- (void)setCharacterSetSlot:(NSInteger)slot;
{
    self.currentCharacterSetSlot = slot;
}

# pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder;
{
    [coder encodeObject:self.startedAt forKey:MMSelfKey(startedAt)];
    [coder encodeObject:self.finishedAt forKey:MMSelfKey(finishedAt)];
    [coder encodeObject:self.displayTextStorage forKey:MMSelfKey(displayTextStorage)];
    [coder encodeInteger:self.removedTrailingNewlineInScrollLine forKey:MMSelfKey(removedTrailingNewlineInScrollLine)];
    [coder encodeObject:self.command forKey:MMSelfKey(command)];
    [coder encodeInteger:self.cursorPositionByCharacters forKey:MMSelfKey(cursorPositionByCharacters)];
    [coder encodeBool:self.hasUsedWholeScreen forKey:MMSelfKey(hasUsedWholeScreen)];
    [coder encodeBool:self.shellCommand forKey:MMSelfKey(shellCommand)];
    [coder encodeBool:self.shellCommandSuccessful forKey:MMSelfKey(shellCommandSuccessful)];
    [coder encodeObject:self.shellCommandAttachment forKey:MMSelfKey(shellCommandAttachment)];
    [coder encodeInteger:self.finishStatus forKey:MMSelfKey(finishStatus)];
    [coder encodeInteger:self.finishCode forKey:MMSelfKey(finishCode)];
}

- (id)initWithCoder:(NSCoder *)decoder;
{
    self = [self init];
    if (!self) {
        return nil;
    }

    self.startedAt = [decoder decodeObjectForKey:MMSelfKey(startedAt)];
    self.finishedAt = [decoder decodeObjectForKey:MMSelfKey(finishedAt)];
    self.displayTextStorage = [decoder decodeObjectForKey:MMSelfKey(displayTextStorage)];
    self.removedTrailingNewlineInScrollLine = [decoder decodeIntegerForKey:MMSelfKey(removedTrailingNewlineInScrollLine)];
    self.command = [decoder decodeObjectForKey:MMSelfKey(command)];
    self.characterOffsetToScreen = [decoder decodeIntegerForKey:MMSelfKey(cursorPositionByCharacters)];
    self.hasUsedWholeScreen = [decoder decodeBoolForKey:MMSelfKey(hasUsedWholeScreen)];
    self.shellCommand = [decoder decodeBoolForKey:MMSelfKey(shellCommand)];
    self.shellCommandSuccessful = [decoder decodeBoolForKey:MMSelfKey(shellCommandSuccessful)];
    self.shellCommandAttachment = [decoder decodeObjectForKey:MMSelfKey(shellCommandAttachment)];
    self.finishStatus = [decoder decodeIntegerForKey:MMSelfKey(finishStatus)];
    self.finishCode = [decoder decodeIntegerForKey:MMSelfKey(finishCode)];

    return self;
}

@end
