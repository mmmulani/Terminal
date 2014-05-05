//
//  MMTestHelpers.h
//  Terminal
//
//  Created by Mehdi Mulani on 6/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

// Usually, when a command outputs a newline, the terminal actually receives "\r\n" because of the termios settings.
// We pass all input through this macro to fake passing through a TTY.
#define SendInputToTask(task, input) \
[task handleCommandOutput:[input stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"]]

#define SendRawInputToTask(task, input) \
[task handleCommandOutput:input]

#define CheckInputAgainstExpectedOutput(input, output) \
do {\
  MMTask *task = [MMTask new]; \
  SendInputToTask(task, input); \
  XCTAssertEqualObjects([task.currentANSIDisplay string], output, @"Compared task output to provided output."); \
} while (0)

#define CheckRawInputAgainstExpectedOutput(input, output) \
do {\
  MMTask *task = [MMTask new]; \
  SendRawInputToTask(task, input); \
  XCTAssertEqualObjects([task.currentANSIDisplay string], output, @"Compared task output to provided output."); \
} while (0)

#define CheckInputAgainstExpectedOutputWithExpectedCursor(input, output, cursorPosition_) \
do {\
  MMTask *task = [MMTask new]; \
  SendInputToTask(task, input); \
  XCTAssertEqualObjects([task.currentANSIDisplay string], output, @"Compared task output to provided output."); \
  XCTAssertEqual(task.cursorPosition.x, cursorPosition_.x, @"X coord of cursor position"); \
  XCTAssertEqual(task.cursorPosition.y, cursorPosition_.y, @"Y coord of cursor position"); \
} while (0)

#define CheckThatInputDoesNotCauseACrash(input) \
do {\
  MMTask *task = [MMTask new]; \
  SendInputToTask(task, input); \
  XCTAssertNotNil([task.currentANSIDisplay string], @""); \
} while (0)

#define CheckInputAgainstExpectedCursorPositionByCharacters(input, cursorPositionByCharacters_) \
do {\
  MMTask *task = [MMTask new]; \
  SendInputToTask(task, input); \
  (void) task.currentANSIDisplay; \
  XCTAssertEqual(task.cursorPositionByCharacters, (NSInteger)cursorPositionByCharacters_, @"Comparing cursor position by characters."); \
} while (0)
