//
//  MMShellMain.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MMTerminalProxy.h"
#import "MMShellProxy.h"

@class MMCommand;

@interface MMShellMain : NSObject <MMShellProxy>

@property (strong) NSConnection *shellConnection;
@property (strong) NSConnection *terminalConnection;
@property NSInteger identifier;
@property NSProxy<MMTerminalProxy> *terminalProxy;

+ (MMShellMain *)sharedApplication;

- (void)startWithIdentifier:(NSInteger)identifier;

@end
