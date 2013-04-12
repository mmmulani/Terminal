//
//  MMTerminalWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTerminalWindowController.h"
#import "MMAppDelegate.h"
#import "MMTask.h"
#import "MMTaskCellViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface MMTerminalWindowController ()

// An index into |self.tasks| of the current task shown in the command input field.
@property NSUInteger commandHistoryIndex;
@property NSString *currentDirectory;

@property CGFloat originalCommandControlsLayoutConstraintConstant;

@end

@implementation MMTerminalWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMTerminalWindow"];

    self.tasks = [NSMutableArray array];
    self.taskViewControllers = [NSMutableArray array];
    self.commandHistoryIndex = 0;

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    self.originalCommandControlsLayoutConstraintConstant = self.commandControlsLayoutConstraint.constant;
}

- (void)handleOutput:(NSString *)message;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        MMTask *lastTask = [self.tasks lastObject];
        [lastTask handleCommandOutput:message withVerbosity:self.logAllCharacters];

        if ([self.taskViewControllers count] == [self.tasks count]) {
            // Force the outputView to re-layout its text and then resize it accordingly.
            MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
            [lastController updateWithANSIOutput];

            [lastController.outputView.layoutManager ensureLayoutForCharacterRange:NSMakeRange(0, 10000)];
            [self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:([self.taskViewControllers count] - 1)]];
            NSLog(@"Updating height of last");
        }

        // XXX: Hack to scroll to bottom after output is added to the screen.
        // Though we inform the NSTableView that a row's height is changed, calling scrollToEndOfDocument: at this point will not scroll to the bottom (possibly due to animations running concurrently).
        // This (hopefully) runs after those animations are done.
        double delayInSeconds = 0.2;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.tableView scrollToEndOfDocument:self];
            NSLog(@"Trying to scroll to bottom");
        });
    });
}

- (void)processFinished;
{
    MMTask *task = [self.tasks lastObject];
    task.finishedAt = [NSDate date];
    self.running = NO;

    MMTaskCellViewController *controller = [self.taskViewControllers lastObject];
    [controller updateWithANSIOutput];

    [self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:([self.taskViewControllers count] - 1)]];
    [self.tableView scrollToEndOfDocument:self];

    [self.window makeFirstResponder:self.commandInput];

    CABasicAnimation *animation = [CABasicAnimation animation];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    animation.duration = 0.5;
    self.commandControlsLayoutConstraint.animations = @{@"constant": animation};

    [self.commandControlsLayoutConstraint.animator setConstant:self.originalCommandControlsLayoutConstraintConstant];
}

- (void)directoryChangedTo:(NSString *)newPath;
{
    self.currentDirectory = newPath;
    [self.currentDirectoryLabel setStringValue:[NSString stringWithFormat:@"Current directory: %@", newPath]];

    NSArray *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:newPath] includingPropertiesForKeys:@[NSURLCustomIconKey, NSURLEffectiveIconKey, NSURLFileResourceTypeKey, NSURLNameKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableArray *directoryCollectionViewData = [NSMutableArray arrayWithCapacity:[fileURLs count]];
    for (NSURL *file in fileURLs) {
        NSDictionary *fileResources = [file resourceValuesForKeys:@[NSURLCustomIconKey, NSURLEffectiveIconKey, NSURLFileResourceTypeKey, NSURLNameKey] error:nil];
        [directoryCollectionViewData addObject:
         @{
         @"name": fileResources[NSURLNameKey],
         @"icon": fileResources[NSURLEffectiveIconKey],
         }];
    }

    // XXX: This is a hack to arrange the items vertically first, then horizontally in the NSCollectionView.
    NSUInteger numberOfRows = 4;

    NSUInteger numberOfColumns = ceil((double)[directoryCollectionViewData count] / (double)numberOfRows);
    [self.directoryCollectionView setMaxNumberOfColumns:numberOfColumns];
    [self.directoryCollectionView setMaxNumberOfRows:numberOfRows];
    NSUInteger numberOfItemsNecessaryForDrawing = numberOfColumns * numberOfRows;
    NSMutableArray *layoutedCollectionViewData = [NSMutableArray arrayWithCapacity:numberOfItemsNecessaryForDrawing];

    for (NSUInteger i = 0; i < numberOfItemsNecessaryForDrawing; i++) {
        layoutedCollectionViewData[i] = @{};
    }

    for (NSUInteger i = 0; i < numberOfItemsNecessaryForDrawing; i++) {
        NSUInteger newRow = i % numberOfRows;
        NSUInteger newColumn = i / numberOfRows;

        NSUInteger newIndex = newRow * numberOfColumns + newColumn;

        if (i < [directoryCollectionViewData count]) {
            layoutedCollectionViewData[newIndex] = directoryCollectionViewData[i];
        }
    }

    self.directoryCollectionView.content = layoutedCollectionViewData;
}

# pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor;
{
    if (self.running) {
        MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
        [self.window makeFirstResponder:lastController.outputView];
    }
    return !self.running;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector;
{
    if (commandSelector == @selector(insertNewline:)) {
        MMAppDelegate *appDelegate = (MMAppDelegate *)[[NSApplication sharedApplication] delegate];
        MMTask *newTask = [MMTask new];
        newTask.command = [textView.string copy];
        newTask.startedAt = [NSDate date];
        [self.tasks addObject:newTask];
        [appDelegate runCommand:newTask.command];

        [textView setString:@""];
        self.commandHistoryIndex = 0;

        [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(self.tasks.count - 1)] withAnimation:NSTableViewAnimationEffectNone];
        [self.tableView scrollToEndOfDocument:self];

        MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
        [self.window makeFirstResponder:lastController.outputView];

        CABasicAnimation *animation = [CABasicAnimation animation];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        animation.duration = 0.5;
        self.commandControlsLayoutConstraint.animations = @{@"constant": animation};

        [self.commandControlsLayoutConstraint.animator setConstant:20.0];

        return YES;
    } else if (commandSelector == @selector(scrollPageUp:)) {
        if (self.tasks.count > 0) {
            if (self.commandHistoryIndex == 0) {
                self.commandHistoryIndex = self.tasks.count - 1;
            } else {
                self.commandHistoryIndex--;
            }
            [textView setString:[(MMTask *)self.tasks[self.commandHistoryIndex] command]];
            return YES;
        }
    }

    return NO;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
{
    // TODO: Handle tilde expansion.

    NSRange whitespaceRange = [textView.string rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:NSBackwardsSearch range:NSMakeRange(0, charRange.location + 1)];
    NSString *partial;
    if (whitespaceRange.location == NSNotFound) {
        partial = [textView.string substringWithRange:NSMakeRange(0, charRange.length + charRange.location)];
    } else {
        partial = [textView.string substringWithRange:NSMakeRange(whitespaceRange.location + 1, charRange.length + (charRange.location - (whitespaceRange.location + 1)))];
    }
    NSLog(@"partial: %@, whitespaceRange: %@", partial, NSStringFromRange(whitespaceRange));

    NSString *absolutePartial = partial;
    if (![partial isAbsolutePath]) {
        absolutePartial = [self.currentDirectory stringByAppendingPathComponent:partial];
    }
    NSArray *matches;
    NSString *longestMatch;
    [absolutePartial completePathIntoString:&longestMatch caseSensitive:NO matchesIntoArray:&matches filterTypes:nil];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:[matches count]];
    NSUInteger startingPosition = [absolutePartial length] - [partial length];
    for (NSString *result in matches) {
        [results addObject:[result substringFromIndex:startingPosition]];
    }

    if ([results count] == 0) {
        return nil;
    }

    // NSString completePathIntoString: will try to complete the path by traversing the directory tree
    // until it finds multiple results. However, we only want to return one directory from that path.
    NSRange slashAfterPartial = [results[0] rangeOfString:@"/" options:0 range:NSMakeRange([partial length] + 1, [results[0] length] - [partial length] - 1)];
    if (slashAfterPartial.location != NSNotFound) {
        return @[[results[0] substringToIndex:slashAfterPartial.location]];
    }

    return results;
}

# pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [self.tasks count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row;
{
    [self _prepareViewControllersUntilRow:row];
    return [(MMTaskCellViewController *)self.taskViewControllers[row] heightToFitAllOfOutput];;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
{
    [self _prepareViewControllersUntilRow:row];
    return [self.taskViewControllers[row] view];
}

- (void)_prepareViewControllersUntilRow:(NSInteger)row;
{
    for (NSInteger i = [self.taskViewControllers count]; i <= row; i++) {
        [self.taskViewControllers addObject:[[MMTaskCellViewController alloc] initWithTask:self.tasks[i]]];
    }
}

@end
