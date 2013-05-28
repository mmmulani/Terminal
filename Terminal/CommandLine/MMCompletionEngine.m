//
//  MMCompletionEngine.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCompletionEngine.h"
#import "MMTerminalConnection.h"
#import "MMCommandLineArgumentsParser.h"
#import "MMCommandsTextView.h"
#import "MMCommandGroup.h"

@interface MMCompletionEngine ()

// These are all values calculated by |prepareCompletions| to be returned by the various NSTextView completion methods.
@property NSRange rangeForTokenUnderCursor;
@property NSRange rangeForPartialToBeCompleted;
@property NSMutableDictionary *escapedCompletionsForPartial;
@property NSArray *displayableCompletionsForPartial;

@end

@implementation MMCompletionEngine

- (NSMutableArray *)completionsForPartial:(NSString *)partial inDirectory:(NSString *)path;
{
    // TODO: Handle tilde expansion.
    if (partial.length == 0) {
        // TODO: Collect information about where the partial is so that we can suggest commands, parameters or files based on context.
        return [self filesAndFoldersInDirectory:path includeHiddenFiles:NO];
    }

    NSString *fileToComplete = [partial characterAtIndex:(partial.length - 1)] == '/' ? @"" : [partial lastPathComponent];
    NSString *prefix = [partial substringToIndex:(partial.length - fileToComplete.length)];
    path = [path stringByAppendingPathComponent:prefix];

    NSArray *files = [self filesAndFoldersInDirectory:path includeHiddenFiles:(fileToComplete.length > 0 && [fileToComplete characterAtIndex:0] == '.')];
    NSMutableArray *matchingFiles = [NSMutableArray arrayWithCapacity:files.count];
    for (NSString *file in files) {
        if (file.length >= fileToComplete.length && [file compare:fileToComplete options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch) range:NSMakeRange(0, fileToComplete.length)] == NSOrderedSame) {
            [matchingFiles addObject:[prefix stringByAppendingString:file]];
        }
    }

    return matchingFiles;
}

- (NSMutableArray *)filesAndFoldersInDirectory:(NSString *)path includeHiddenFiles:(BOOL)hiddenFiles;
{
    NSArray *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:path] includingPropertiesForKeys:@[NSURLNameKey, NSURLFileResourceTypeKey] options:(hiddenFiles ? 0 : NSDirectoryEnumerationSkipsHiddenFiles) error:nil];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:[fileURLs count]];
    for (NSURL *file in fileURLs) {
        NSDictionary *resourceValues = [file resourceValuesForKeys:@[NSURLNameKey, NSURLFileResourceTypeKey] error:nil];
        // We append a "/" to the end of the name if the file is a directory.
        NSString *fileNameWithSuffix = [resourceValues[NSURLNameKey] stringByAppendingString:([resourceValues[NSURLFileResourceTypeKey] isEqualToString:NSURLFileResourceTypeDirectory] ? @"/" : @"")];
        // The strings returned by NSFileManager have seperate characters for diacratics.
        // For example, "á" would have length 2. Calling |precomposedStringWithCanonicalMapping| composes these characters and diacratics into a single character.
        [files addObject:fileNameWithSuffix.precomposedStringWithCanonicalMapping];
    }
    return files;
}

- (NSRange)tokenContainingPosition:(NSInteger)position;
{
    // TODO: Handle a tab completion like: cd "Calibre<cursor here><TAB> ; echo test
    // Maybe we can accomplish this by taking a substring up to the cursor and parsing with a special "partial" rule.
    NSArray *tokens = [MMCommandLineArgumentsParser tokensFromCommandLineWithoutEscaping:self.commandsTextView.string];
    NSArray *tokenEndings = [MMCommandLineArgumentsParser tokenEndingsFromCommandLine:self.commandsTextView.string];

    for (NSInteger i = 0; i < tokens.count; i++) {
        NSInteger tokenEnd = [tokenEndings[i] integerValue];
        NSInteger tokenStart = tokenEnd - [tokens[i] length];
        if (tokenEnd >= position && tokenStart <= position) {
            return NSMakeRange(tokenStart, position - tokenStart);
        }
    }

    return NSMakeRange(NSNotFound, 0);
}

- (void)prepareCompletions;
{
    // This handles the 4 step process around preparing completions to be displayed.
    // 1. Recognize what is to be completed, i.e. what "word", and determine the relevant context around the word.
    // 2. Extract a partial from that "word" and convert it into the form in which it will be interpreted.
    //    (This usually means escaping it.)
    // 3. Calculate completions given the interpreted partial and its context.
    // 4. Convert completions into the form that they will be typed for insertion.

    // Step 1.
    NSInteger currentPosition = self.commandsTextView.selectedRange.location;
    self.rangeForTokenUnderCursor = [self tokenContainingPosition:currentPosition];
    if (self.rangeForTokenUnderCursor.location == NSNotFound) {
        self.rangeForTokenUnderCursor = NSMakeRange(currentPosition, 0);
    }
    NSString *argument = [self.commandsTextView.string substringWithRange:self.rangeForTokenUnderCursor];

    // Step 2.
    // TODO: Support double-quoted arguments.
    // We want to separate the argument into the path prefix and the path being completed.
    NSRegularExpression *pathComponentRegEx = [NSRegularExpression regularExpressionWithPattern:@"((\\.)|[^/])*$" options:0 error:NULL];
    NSRange partialRange = [pathComponentRegEx rangeOfFirstMatchInString:argument options:0 range:NSMakeRange(0, argument.length)];
    NSString *partialPrefix = [MMCommand unescapeArgument:[argument substringToIndex:partialRange.location]];
    NSString *partial = [MMCommand unescapeArgument:[argument substringWithRange:partialRange]];
    self.rangeForPartialToBeCompleted = NSMakeRange(self.rangeForTokenUnderCursor.location + partialRange.location, partialRange.length);

    // Step 3.
    NSString *path = [partialPrefix stringByExpandingTildeInPath];
    if (![path isAbsolutePath]) {
        path = [self.terminalConnection.currentDirectory stringByAppendingPathComponent:partialPrefix];
    }
    self.displayableCompletionsForPartial = [self completionsForPartial:partial inDirectory:path];

    // Step 4.
    self.escapedCompletionsForPartial = [NSMutableDictionary dictionary];
    for (NSString *completion in self.displayableCompletionsForPartial) {
        self.escapedCompletionsForPartial[completion] = [MMCommand escapeArgument:completion];
    }
}

- (NSString *)typeableCompletionForDisplayCompletion:(NSString *)displayableCompletion;
{
    return self.escapedCompletionsForPartial[displayableCompletion];
}

- (NSString *)singleCompletionOrNil;
{
    if (self.displayableCompletionsForPartial.count != 1) {
        return nil;
    }

    return self.displayableCompletionsForPartial[0];
}

# pragma mark - NSTextView methods

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
{
    return self.displayableCompletionsForPartial;
}

- (NSRange)rangeForUserCompletion;
{
    return self.rangeForPartialToBeCompleted;
}

@end
