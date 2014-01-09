//
//  MMTerminalConnectionInternal.h
//  Terminal
//
//  Created by Mehdi Mulani on 1/5/14.
//  Copyright (c) 2014 Mehdi Mulani. All rights reserved.
//

#import "MMTerminalConnection.h"

@interface MMTerminalConnection (Internal)

@property NSTask *shellTask;
@property NSPipe *shellErrorPipe;
@property NSPipe *shellInputPipe;
@property NSPipe *shellOutputPipe;
@property NSString *unreadInitialOutput;

- (void)_startRemoteShell;

@end
