//
//  MMTerminalProxy.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MMShellCommands.h"

typedef enum {
    MMProcessStatusError,
    MMProcessStatusExit,
    MMProcessStatusSignal,
    MMProcessStatusStopped,
} MMProcessStatus;

typedef NSInteger MMTaskIdentifier;

@protocol MMTerminalProxy <NSObject>

- (void)processFinished:(MMProcessStatus)status data:(id)data;
- (void)directoryChangedTo:(NSString *)newPath;
- (void)shellCommand:(MMShellCommand)command succesful:(BOOL)success attachment:(id)attachment;

@end
