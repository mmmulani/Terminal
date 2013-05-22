//
//  MMANSIAction.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/21/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MMANSIActionDelegate;

@interface MMANSIAction : NSObject

@property NSArray *arguments;
@property NSMutableDictionary *data;
@property id<MMANSIActionDelegate> delegate;

+ (NSArray *)defaultArguments;

- (id)initWithArguments:(NSArray *)arguments;

- (id)defaultedArgumentAtIndex:(NSInteger)index;

- (void)setUp;
- (void)tearDown;
- (void)do;

@end

@protocol MMANSIActionDelegate <NSObject>

// These x, y and row positions are all 1-indexed to match with the ANSI positioning system.
// (i.e. 1 <= x <= termWidth and 1 <= row, y <= termHeight)

- (NSInteger)cursorPositionX;
- (NSInteger)cursorPositionY;
- (NSInteger)termHeight;
- (NSInteger)termWidth;
- (NSInteger)scrollMarginTop;
- (NSInteger)scrollMarginBottom;

- (void)setCursorToX:(NSInteger)x Y:(NSInteger)y;
- (NSInteger)numberOfCharactersInScrollRow:(NSInteger)row;
- (BOOL)isScrollRowTerminatedInNewline:(NSInteger)row;
- (NSInteger)numberOfRowsOnScreen;

- (void)replaceCharactersAtScrollRow:(NSInteger)row scrollColumn:(NSInteger)column withString:(NSString *)replacementString;

- (void)insertBlankLineAtScrollRow:(NSInteger)row withNewline:(BOOL)newline;
- (void)removeLineAtScrollRow:(NSInteger)row;
- (void)setScrollRow:(NSInteger)row hasNewline:(BOOL)hasNewline;

// XXX: Try to remove these or change them to ensure that all calculations for ANSIActions can be done in |setUp|.
- (void)checkIfExceededLastLineAndObeyScrollMargin:(BOOL)obeyScrollMargin;
- (unichar)ansiCharacterAtScrollRow:(NSUInteger)scrollRow column:(NSUInteger)column;

@end