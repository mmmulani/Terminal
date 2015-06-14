//
//  MMANSITerminalViewSnapshotTests.m
//  Terminal
//
//  Created by Mehdi Mulani on 14/06/2015.
//  Copyright © 2015 Mehdi Mulani. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MMTask.h"
#import "MMTextView.h"

@interface MMANSITerminalViewSnapshotTests : XCTestCase

@end

@implementation MMANSITerminalViewSnapshotTests

- (void)snapshotCompareOutput:(NSString *)output size:(NSSize)size withIdentifier:(NSString *)identifier
{
  NSRect testRect = NSMakeRect(0, 0, size.width, size.height);

  MMTextView *textView = [[MMTextView alloc] initWithFrame:testRect];
  MMTask *task = [MMTask new];
  [textView setTextStorage:task.displayTextStorage];

  [task handleCommandOutput:output];

  [textView setFrame:testRect];
  NSBitmapImageRep* rep = [textView bitmapImageRepForCachingDisplayInRect:testRect];
  [textView cacheDisplayInRect:testRect toBitmapImageRep:rep];
  NSData *data = [rep representationUsingType:NSPNGFileType properties:@{}];

  NSMutableString *imagePath = [NSMutableString string];
  [imagePath appendString:[NSProcessInfo processInfo].environment[@"TEST_REFERENCE_IMAGE_DIR"]];
  [imagePath appendString:@"/"];
  [imagePath appendString:NSStringFromSelector(self.invocation.selector)];
  if (identifier) {
    [imagePath appendFormat:@"_%@", identifier];
  }
  if ([[NSScreen mainScreen] backingScaleFactor] > 1) {
    [imagePath appendFormat:@"@%.fx", [[NSScreen mainScreen] backingScaleFactor]];
  }
  [imagePath appendString:@".png"];

  NSError *error;
  XCTAssertTrue([data writeToFile:imagePath options:NSDataWritingAtomic error:&error], @"Unable to write snapshot file with error %@", error);
}

- (void)testExample {
  [self snapshotCompareOutput:@"TEST" size:NSMakeSize(200, 200) withIdentifier:nil];
}

@end
