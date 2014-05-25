//
//  MMTextView.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTextView.h"

#import "MMTask.h"

@implementation MMTextView

- (void)awakeFromNib
{
  _layoutManager = [[NSLayoutManager alloc] init];
  [self setAutoresizingMask:NSViewNotSizable];
}

- (void)setTextStorage:(NSTextStorage *)textStorage
{
  [self.layoutManager replaceTextStorage:textStorage];
  textStorage.delegate = self;
}

- (NSTextStorage *)textStorage
{
  return self.layoutManager.textStorage;
}

- (void)setSelectedRange:(NSRange)charRange
{
  // TODO: Handle a cursor position.
}

# pragma mark - Event handling

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)keyDown:(NSEvent *)theEvent;
{
  [self.delegate handleKeyPress:theEvent];
}

- (void)paste:(id)sender;
{
  NSString *pasteboardString = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
  [self.delegate handleInput:pasteboardString];
}

# pragma mark - NSTextStorageDelegate methods

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
  [self setSizeForRowsOfText:self.task.totalRowsInOutput columns:self.task.termWidth];

  [self setNeedsLayout:YES];
  [self setNeedsDisplay:YES];
}

# pragma mark - Text sizing

- (CGFloat)desiredScrollHeight
{
  NSUInteger rows = MIN(self.task.totalRowsInOutput, self.task.termHeight);
  return [[self class] heightForRowsOfText:rows];
}

+ (CGFloat)widthForColumnsOfText:(NSUInteger)columns
{
  CGFloat characterWidth = [[MMTask taskFont] maximumAdvancement].width;
  return ceil(characterWidth * columns) + 1;
}

+ (NSUInteger)columnsForWidthOfText:(CGFloat)width
{
  CGFloat characterWidth = [[MMTask taskFont] maximumAdvancement].width;
  return floor(width / characterWidth);
}

+ (CGFloat)heightForRowsOfText:(NSUInteger)rows
{
  CGFloat characterHeight = [[[NSLayoutManager alloc] init] defaultLineHeightForFont:[MMTask taskFont]];
  return ceil(characterHeight * rows) + 1;
}

- (void)setSizeForRowsOfText:(NSUInteger)rows columns:(NSUInteger)columns
{
  CGFloat height = [[self class] heightForRowsOfText:rows];
  CGFloat width = [[self class] widthForColumnsOfText:columns];

  [self setFrameSize:NSMakeSize(width, height)];
}

# pragma mark - Text drawing

- (void)drawRect:(NSRect)dirtyRect
{
  CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);

  CGMutablePathRef path = CGPathCreateMutable();
  CGRect bounds = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height);
  CGPathAddRect(path, NULL, bounds);

  CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFMutableAttributedStringRef)self.textStorage);

  CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);

  CFRelease(framesetter);
  CTFrameDraw(frame, ctx);
  CFRelease(frame);
}

# pragma mark - Focus ring drawing

- (BOOL)becomeFirstResponder;
{
  [self.window addObserver:self forKeyPath:@"firstResponder" options:NSKeyValueObservingOptionInitial context:NULL];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFocusRing) name:NSWindowDidResignKeyNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFocusRing) name:NSWindowDidBecomeKeyNotification object:nil];

  return [super becomeFirstResponder];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
  if ([keyPath isEqualToString:@"firstResponder"]) {
    [self updateFocusRing];

    if (![self.window.firstResponder isEqual:self]) {
      [self.window removeObserver:self forKeyPath:@"firstResponder"];
      [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
  }
}

- (void)updateFocusRing;
{
  [self.enclosingScrollView setKeyboardFocusRingNeedsDisplayInRect:self.enclosingScrollView.bounds];
}

@end
