//
//  MMCommandsTextView.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandsTextView.h"
#import "MMCompletionEngine.h"

@implementation MMCommandsTextView

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return nil;
    }

    self.completionEngine = [[MMCompletionEngine alloc] init];
    self.completionEngine.commandsTextView = self;

    return self;
}

- (void)complete:(id)sender;
{
    [self.completionEngine prepareCompletions];
    NSString *singleCompletion = self.completionEngine.singleCompletionOrNil;
    if (singleCompletion) {
        [self replaceCharactersInRange:self.rangeForUserCompletion withString:[self.completionEngine typeableCompletionForDisplayCompletion:singleCompletion]];
    } else {
        [super complete:sender];
    }
}

- (NSRange)rangeForUserCompletion;
{
    return [self.completionEngine rangeForUserCompletion];
}

- (void)insertCompletion:(NSString *)word forPartialWordRange:(NSRange)charRange movement:(NSInteger)movement isFinal:(BOOL)flag;
{
    [super insertCompletion:[self.completionEngine typeableCompletionForDisplayCompletion:word] forPartialWordRange:charRange movement:movement isFinal:flag];
}

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
{
    return [self.completionEngine completionsForPartialWordRange:charRange indexOfSelectedItem:index];
}

- (BOOL)isContinuousSpellCheckingEnabled;
{
    // Disable spell checking.
    return NO;
}

@end
