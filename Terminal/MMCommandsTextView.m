//
//  MMCommandsTextView.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandsTextView.h"
#import "MMCommandLineArgumentsParser.h"
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
    // TODO: Handle a tab completion like: cd "Calibre<cursor here><TAB> ; echo test
    // Maybe we can accomplish this by taking a substring up to the cursor and parsing with a special "partial" rule.
    NSArray *commands = [MMCommandLineArgumentsParser parseCommandsFromCommandLineWithoutEscaping:self.string];
    NSArray *tokenEndings = [MMCommandLineArgumentsParser tokenEndingsFromCommandLine:self.string];

    NSInteger currentPosition = self.selectedRange.location;
    for (NSInteger i = 0; i < commands.count; i++) {
        for (NSInteger j = 0; j < [commands[i] count]; j++) {
            NSInteger tokenEnd = [tokenEndings[i][j] integerValue];
            NSInteger tokenStart = tokenEnd - [commands[i][j] length];
            if (tokenEnd >= currentPosition && tokenStart <= currentPosition) {
                return NSMakeRange(tokenStart, currentPosition - tokenStart);
            }
        }
    }

    return NSMakeRange(currentPosition, 0);
}

- (void)insertCompletion:(NSString *)word forPartialWordRange:(NSRange)charRange movement:(NSInteger)movement isFinal:(BOOL)flag;
{
    NSLog(@"insertCompletion:%@ forPartialWordRange:%@ movement:%ld isFinal:%d", word, NSStringFromRange(charRange), (long)movement, flag);
    [super insertCompletion:word forPartialWordRange:charRange movement:movement isFinal:flag];
}

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
{
    return [self.completionEngine completionsForPartialWordRange:charRange indexOfSelectedItem:index];
}

@end
