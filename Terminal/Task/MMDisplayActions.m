//
//  MMDisplayActions.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/1/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMDisplayActions.h"

@implementation MMDECAlignmentTest

- (void)do;
{
    // This is the DEC Screen Alignment Test and is activated by \033#8.
    // It fills the screen with the letter "E".

    NSInteger numberOfRowsToCreate = self.delegate.termHeight - self.delegate.numberOfRowsOnScreen;
    for (NSInteger i = 0; i < numberOfRowsToCreate; i++) {
        [self.delegate insertBlankLineAtScrollRow:(self.delegate.termHeight - numberOfRowsToCreate + i + 1) withNewline:NO];
    }

    NSString *alignmentText = [@"" stringByPaddingToLength:self.delegate.termWidth withString:@"E" startingAtIndex:0];
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
        [self.delegate setDECPrivateMode:(MMDECMode)[argument integerValue] on:NO];
    }
}

@end

@implementation MMDECPrivateModeSet

- (void)do;
{
    for (NSString *argument in self.arguments) {
        [self.delegate setDECPrivateMode:(MMDECMode)[argument integerValue] on:YES];
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