//
//  MMShellMain.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMCommand;

@interface MMShellMain : NSObject

@property (strong) NSConnection *shellConnection;
@property (strong) NSConnection *terminalConnection;
@property NSInteger identifier;

+ (MMShellMain *)sharedApplication;

- (void)startWithIdentifier:(NSInteger)identifier;
- (void)executeCommand:(MMCommand *)command;

@end
