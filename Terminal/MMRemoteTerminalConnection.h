//
//  MMRemoteTerminalConnection.h
//  Terminal
//
//  Created by Mehdi Mulani on 7/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTerminalConnection.h"

@interface MMRemoteTerminalConnection : MMTerminalConnection

- (void)setUpRemoteTerminalConnectionWithSSHTask:(NSTask *)sshTask initialOutput:(NSString *)initialOutput;

@end
