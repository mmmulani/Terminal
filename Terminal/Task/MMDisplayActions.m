//
//  MMDisplayActions.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/1/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMDisplayActions.h"
#import "NSString+MMAdditions.h"

@implementation MMDECAlignmentTest

- (void)do;
{
    // This is the DEC Screen Alignment Test and is activated by \033#8.
    // It fills the screen with the letter "E".

    NSInteger numberOfRowsToCreate = self.delegate.termHeight - self.delegate.numberOfRowsOnScreen;
    for (NSInteger i = 0; i < numberOfRowsToCreate; i++) {
        [self.delegate insertBlankLineAtScrollRow:(self.delegate.termHeight - numberOfRowsToCreate + i + 1) withNewline:NO];
    }

    NSString *alignmentText = [@"E" repeatedTimes:self.delegate.termWidth];
    for (NSInteger i = 1; i <= self.delegate.termHeight; i++) {
        [self.delegate replaceCharactersAtScrollRow:i scrollColumn:1 withString:alignmentText];
        [self.delegate setScrollRow:i hasNewline:(i != self.delegate.termHeight)];
    }
}

@end

@implementation MMFullReset

- (void)do;
{
    // This is the Full Reset (RIS) and is activated by \033c.
    // It should reset the terminal to its starting mode, e.g. reset any terminal changes that have been made.

    // TODO: Reset colour and tab settings.
    for (NSInteger i = self.delegate.numberOfRowsOnScreen; i > 0; i--) {
        [self.delegate removeLineAtScrollRow:1];
    }

    [self.delegate insertBlankLineAtScrollRow:1 withNewline:NO];
    [self.delegate setCursorToX:1 Y:1];

    self.delegate.G0CharacterSet = MMCharacterSetUSASCII;
    self.delegate.G1CharacterSet = MMCharacterSetUSASCII;
    self.delegate.G2CharacterSet = MMCharacterSetUSASCII;
    self.delegate.G3CharacterSet = MMCharacterSetUSASCII;
    [self.delegate setCharacterSetSlot:0];
}

@end

@implementation MMBeep

- (void)do;
{
    NSBeep();
}

@end

@implementation MMDECPrivateModeReset

- (void)do;
{
    for (NSString *argument in self.arguments) {
        MMDECMode mode = (MMDECMode)[argument integerValue];
        [self.delegate setDECPrivateMode:mode on:NO];

        if (mode == MMDECModeWideColumn) {
            if ([self.delegate isDECPrivateModeSet:MMDECModeAllowColumnChange]) {
                [self.delegate tryToResizeTerminalForColumns:80 rows:self.delegate.termHeight];
                MMANSIAction *action = [MMFullReset new];
                action.delegate = self.delegate;
                [action do];
            }
        }
    }
}

@end

@implementation MMDECPrivateModeSet

- (void)do;
{
    for (NSString *argument in self.arguments) {
        MMDECMode mode = (MMDECMode)[argument integerValue];
        [self.delegate setDECPrivateMode:mode on:YES];

        if (mode == MMDECModeWideColumn) {
            if ([self.delegate isDECPrivateModeSet:MMDECModeAllowColumnChange]) {
                [self.delegate tryToResizeTerminalForColumns:132 rows:self.delegate.termHeight];
                MMANSIAction *action = [MMFullReset new];
                action.delegate = self.delegate;
                [action do];

            }
        }
    }
}

@end

@implementation MMANSIModeReset

- (void)do;
{
    for (NSString *argument in self.arguments) {
        [self.delegate setANSIMode:(MMANSIMode)[argument integerValue] on:NO];
    }
}

@end

@implementation MMANSIModeSet

- (void)do;
{
    for (NSString *argument in self.arguments) {
        [self.delegate setANSIMode:(MMANSIMode)[argument integerValue] on:YES];
    }
}

@end

@implementation MMCharacterSetDesignation

- (void)do;
{
    NSAssert(self.arguments.count == 2, @"Must be provided a slot and a character set");
    unichar escapeCode = [self.arguments[0] charValue];
    unichar characterSetChar = [self.arguments[1] charValue];
    MMCharacterSet characterSet;

    switch (characterSetChar) {
        case 'B':
            characterSet = MMCharacterSetUSASCII;
            break;
        case '0':
            characterSet = MMCharacterSetDECLineDrawing;
            break;
        case 'A':
            characterSet = MMCharacterSetUnitedKingdom;
            break;
        case 'E':
        case '6':
            characterSet = MMCharacterSetNorwegian;
            break;
        case '4':
            characterSet = MMCharacterSetDutch;
            break;
        case 'C':
        case '5':
            characterSet = MMCharacterSetFinnish;
            break;
        case 'R':
            characterSet = MMCharacterSetFrench;
            break;
        case 'Q':
            characterSet = MMCharacterSetFrenchCanadian;
            break;
        case 'K':
            characterSet = MMCharacterSetGerman;
            break;
        case 'Y':
            characterSet = MMCharacterSetItalian;
            break;
        case 'Z':
            characterSet = MMCharacterSetSpanish;
            break;
        case 'H':
        case '7':
            characterSet = MMCharacterSetSwedish;
            break;
        case '=':
            characterSet = MMCharacterSetSwiss;
            break;
    }

    if (escapeCode == '(') {
        self.delegate.G0CharacterSet = characterSet;
    } else if (escapeCode == ')') {
        self.delegate.G1CharacterSet = characterSet;
    } else if (escapeCode == '*') {
        self.delegate.G2CharacterSet = characterSet;
    } else if (escapeCode == '+') {
        self.delegate.G3CharacterSet = characterSet;
    }
}

@end

@implementation MMCharacterSetInvocation

+ (NSArray *)_defaultArguments { return @[@0]; }

- (void)do;
{
    [self.delegate setCharacterSetSlot:[[self defaultedArgumentAtIndex:0] integerValue]];
}

@end

@implementation MMCharacterAttributes

- (void)do;
{
    [self.delegate handleCharacterAttributes:self.arguments];
}

@end