//
//  MMShellMain.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMShellMain : NSObject

@property (strong) NSConnection *shellConnection;

+ (MMShellMain *)sharedApplication;

- (void)start;
- (void)executeCommand:(NSString *)command;

@end
