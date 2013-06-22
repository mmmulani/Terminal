//
//  MMUtilities.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/31/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMUtilities : NSObject

+ (void)postData:(NSData *)data toURL:(NSURL *)url description:(NSString *)description;
+ (NSMutableArray *)filesAndFoldersInDirectory:(NSString *)path includeHiddenFiles:(BOOL)hiddenFiles;

@end
