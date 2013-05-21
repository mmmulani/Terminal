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

- (NSInteger)cursorPositionX;
- (NSInteger)cursorPositionY;
- (NSInteger)termHeight;
- (NSInteger)termWidth;

- (void)setCursorToX:(NSInteger)x Y:(NSInteger)y;

// XXX: Try to remove these or change them to ensure that all calculations for ANSIActions can be done in |setUp|.
- (void)checkIfExceededLastLineAndObeyScrollMargin:(BOOL)obeyScrollMargin;
- (unichar)ansiCharacterAtScrollRow:(NSUInteger)scrollRow column:(NSUInteger)column;

@end