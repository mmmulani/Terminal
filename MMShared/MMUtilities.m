//
//  MMUtilities.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/31/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMUtilities.h"

@implementation MMUtilities

+ (void)postData:(NSData *)data toURL:(NSURL *)url description:(NSString *)description;
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
    [request setValue:description forHTTPHeaderField:@"MMFilename"];
    [request setHTTPBody:data];

    NSURLResponse *response;
    NSError *error;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error) {
        NSLog(@"Error in sending request: %@", error);
    }
}

+ (NSMutableArray *)filesAndFoldersInDirectory:(NSString *)path includeHiddenFiles:(BOOL)hiddenFiles;
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

@end
