//
//  MMTaskInfo.m
//  Terminal
//
//  Created by Mehdi on 2013-06-15.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTaskInfo.h"
#import "MMShared.h"

@implementation MMTaskInfo

# pragma mark - NSCoding and NSPortCoder

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder;
{
  if ([encoder isByref]) {
    return [super replacementObjectForPortCoder:encoder];
  } else {
    return self;
  }
}

- (id)initWithCoder:(NSCoder *)decoder;
{
  self = [super init];
  if (!self) {
    return nil;
  }

  self.command = [decoder decodeObjectForKey:MMSelfKey(command)];
  self.commandGroups = [decoder decodeObjectForKey:MMSelfKey(commandGroups)];
  self.shellCommand = [decoder decodeBoolForKey:MMSelfKey(shellCommand)];
  self.identifier = [decoder decodeIntegerForKey:MMSelfKey(identifier)];

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
  [coder encodeObject:self.command forKey:MMSelfKey(command)];
  [coder encodeObject:self.commandGroups forKey:MMSelfKey(commandGroups)];
  [coder encodeBool:self.shellCommand forKey:MMSelfKey(shellCommand)];
  [coder encodeInteger:self.identifier forKey:MMSelfKey(identifier)];
}

@end
