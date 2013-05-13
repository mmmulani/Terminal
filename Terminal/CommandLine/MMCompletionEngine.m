//
//  MMCompletionEngine.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCompletionEngine.h"
#import "MMTerminalConnection.h"
#import "MMCommandsTextView.h"

@implementation MMCompletionEngine

- (NSArray *)completionsForPartial:(NSString *)partial inDirectory:(NSString *)path;
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

- (NSArray *)filesAndFoldersInDirectory:(NSString *)path includeHiddenFiles:(BOOL)hiddenFiles;
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

# pragma mark - NSTextView methods

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
{
    NSLog(@"Partial substring: %@", [self.commandsTextView.string substringWithRange:charRange]);
    NSString *partial = [self.commandsTextView.string substringWithRange:charRange];

    NSArray *results = [self completionsForPartial:partial inDirectory:self.terminalConnection.currentDirectory];

    return results;
}

@end
