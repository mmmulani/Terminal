//
//  MMCompletionEngine.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCompletionEngine.h"

@implementation MMCompletionEngine

+ (MMCompletionEngine *)defaultCompletionEngine;
{
    static MMCompletionEngine *completionEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        completionEngine = [[[self class] alloc] init];
    });

    return completionEngine;
}

- (NSArray *)completionsForPartial:(NSString *)partial inDirectory:(NSString *)path;
{
    // TODO: Handle tilde expansion.
    if (partial.length == 0) {
        // TODO: Collect information about where the partial is so that we can suggest commands, parameters or files based on context.
        return [self filesAndFoldersInDirectory:path includeHiddenFiles:NO];
    }
    NSString *absolutePartial = partial;
    if (![partial isAbsolutePath]) {
        absolutePartial = [path stringByAppendingPathComponent:partial];
    }
    NSString *fileToComplete = [[absolutePartial pathComponents] lastObject];
    NSString *prefix = [partial substringToIndex:(partial.length - fileToComplete.length)];

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
    NSArray *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:path] includingPropertiesForKeys:@[NSURLNameKey] options:(hiddenFiles ? 0 : NSDirectoryEnumerationSkipsHiddenFiles) error:nil];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:[fileURLs count]];
    for (NSURL *file in fileURLs) {
        [files addObject:[file resourceValuesForKeys:@[NSURLNameKey] error:nil][NSURLNameKey]];
    }
    return files;
}

@end
