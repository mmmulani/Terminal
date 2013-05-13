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

@end
