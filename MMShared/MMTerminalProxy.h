//
//  MMTerminalProxy.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MMShellCommands.h"

typedef NS_ENUM(NSInteger, MMProcessStatus) {
  MMProcessStatusError,
  MMProcessStatusExit,
  MMProcessStatusSignal,
  MMProcessStatusStopped,
};

typedef NSInteger MMTaskIdentifier;
typedef NSInteger MMShellIdentifier;

@protocol MMTerminalProxy <NSObject>

- (void)shellStartedWithIdentifier:(MMShellIdentifier)identifier;
- (void)directoryChangedTo:(NSString *)newPath;

- (void)taskFinished:(MMTaskIdentifier)taskIdentifier status:(MMProcessStatus)status data:(id)data;
- (void)taskFinished:(MMTaskIdentifier)taskIdentifier shellCommand:(MMShellCommand)command succesful:(BOOL)success attachment:(id)attachment;

@end
