//
//  MMTerminalWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#include <sys/event.h>

#import "MMTerminalWindowController.h"
#import "MMAppDelegate.h"
#import "MMShared.h"
#import "MMTask.h"
#import "MMTaskCellViewController.h"
#import "MMParserContext.h"
#import <QuartzCore/QuartzCore.h>

@interface MMTerminalWindowController ()

// An index into |self.tasks| of the current task shown in the command input field.
@property NSUInteger commandHistoryIndex;
@property NSString *currentDirectory;

@property CGFloat originalCommandControlsLayoutConstraintConstant;

@property NSMutableDictionary *directoriesBeingWatched;
@property CFFileDescriptorRef directoryKqRef;

@end

@implementation MMTerminalWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMTerminalWindow"];

    self.tasks = [NSMutableArray array];
    self.taskViewControllers = [NSMutableArray array];
    self.commandHistoryIndex = 0;
    self.directoriesBeingWatched = [NSMutableDictionary dictionary];

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminalOutputFrameChanged:) name:NSViewFrameDidChangeNotification object:self.tableView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminalOutputFrameChanged:) name:NSViewFrameDidChangeNotification object:self.tableView.superview];

    self.originalCommandControlsLayoutConstraintConstant = self.commandControlsLayoutConstraint.constant;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)terminalOutputFrameChanged:(NSNotification *)notification;
{
    // TODO: Add a check to see if we are already scrolled to the bottom, and only scroll down then.
    NSRect clipViewFrame = self.tableView.superview.frame;
    [((NSClipView *)self.tableView.superview) scrollToPoint:NSMakePoint(0, self.tableView.frame.size.height - clipViewFrame.size.height)];
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
        }
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

    [self.window makeFirstResponder:self.commandInput];

    CABasicAnimation *animation = [CABasicAnimation animation];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    animation.duration = 0.25;
    self.commandControlsLayoutConstraint.animations = @{@"constant": animation};

    [self.commandControlsLayoutConstraint.animator setConstant:self.originalCommandControlsLayoutConstraintConstant];
}

- (void)directoryChangedTo:(NSString *)newPath;
{
    if (self.currentDirectory) {
        [self unregisterDirectory:self.currentDirectory];
    }
    self.currentDirectory = newPath;
    [self registerDirectoryToBeObserved:newPath];

    [self updateDirectoryView:newPath];
}

- (void)updateDirectoryView:(NSString *)directoryPath;
{
    [self.currentDirectoryLabel setStringValue:[NSString stringWithFormat:@"Current directory: %@", directoryPath]];

    NSArray *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directoryPath] includingPropertiesForKeys:@[NSURLCustomIconKey, NSURLEffectiveIconKey, NSURLFileResourceTypeKey, NSURLNameKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
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

# pragma mark - Directory watching

- (void)directoryModified:(NSString *)path;
{
    if ([self.currentDirectory isEqualToString:path]) {
        [self updateDirectoryView:path];
    }
}

- (void)registerDirectoryToBeObserved:(NSString *)path;
{
    // TODO: Support multiple directories being observed. Maybe accomplish this by storing kqRefs instead of FDs in |directoriesBeingWatched|.

    if (self.directoriesBeingWatched[path]) {
        return;
    }

    int dirFD = open([path fileSystemRepresentation], O_EVTONLY);
    if (dirFD < 0) {
        MMLog(@"Ran into problem observing %@.", path);
        return;
    }

    int kq = kqueue();
    if (kq < 0) {
        MMLog(@"Ran into a problem running kqueue() while observing %@.", path);
        close(dirFD);
        return;
    }

    struct kevent event;
    event.ident = dirFD;
    event.filter = EVFILT_VNODE;
    event.flags = EV_ADD | EV_CLEAR;
    event.fflags = NOTE_WRITE;
    event.data = 0;
    event.udata = NULL;

    self.directoriesBeingWatched[path] = [NSNumber numberWithUnsignedLong:event.ident];

    if (kevent(kq, &event, 1, NULL, 0, NULL)) {
        MMLog(@"Ran into a problem with kevent() while observing %@.", path);
        close(kq);
        close(dirFD);
        return;
    }

    CFFileDescriptorContext context = { 0, (__bridge void *)self, NULL, NULL, NULL };
    self.directoryKqRef = CFFileDescriptorCreate(NULL, kq, true, directoryWatchingCallback, &context);
    if (!self.directoryKqRef) {
        MMLog(@"Ran into a problem creating a file descriptor for kq while observing %@,", path);
        close(kq);
        close(dirFD);
        return;
    }

    CFRunLoopSourceRef runLoopSourceRef = CFFileDescriptorCreateRunLoopSource(NULL, self.directoryKqRef, 0);
    if (!runLoopSourceRef) {
        MMLog(@"Ran into a problem creating a run loop source while observing %@,", path);
        CFFileDescriptorInvalidate(self.directoryKqRef);
        close(dirFD);
        return;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSourceRef, kCFRunLoopDefaultMode);
    CFRelease(runLoopSourceRef);

    CFFileDescriptorEnableCallBacks(self.directoryKqRef, kCFFileDescriptorReadCallBack);
}

- (void)unregisterDirectory:(NSString *)path;
{
    NSAssert(self.directoriesBeingWatched[path], @"Directory must be currently watched");
    int kq = CFFileDescriptorGetNativeDescriptor(self.directoryKqRef);
    NSAssert(kq > 0, @"kq should exist.");

    CFFileDescriptorDisableCallBacks(self.directoryKqRef, kCFFileDescriptorReadCallBack);
    CFFileDescriptorInvalidate(self.directoryKqRef);
    CFRelease(self.directoryKqRef);
    self.directoryKqRef = NULL;
    close([self.directoriesBeingWatched[path] intValue]);
    [self.directoriesBeingWatched removeObjectForKey:path];
}

static void directoryWatchingCallback(CFFileDescriptorRef kqRef, CFOptionFlags callBackTypes, void *info) {
    int kq = CFFileDescriptorGetNativeDescriptor(((__bridge MMTerminalWindowController *)info).directoryKqRef);
    if (kq < 0) {
        return;
    }

    struct kevent event;
    struct timespec timeout = { 0, 0 };
    if (kevent(kq, NULL, 0, &event, 1, &timeout) == 1) {
        NSArray *directories = [((__bridge MMTerminalWindowController *)info).directoriesBeingWatched allKeysForObject:[NSNumber numberWithUnsignedLong:event.ident]];
        MMLog(@"Directories modified: %@", directories);
        for (NSString *path in directories) {
            [((__bridge MMTerminalWindowController *)info) directoryModified:path];
        }
    }

    CFFileDescriptorEnableCallBacks(((__bridge MMTerminalWindowController *)info).directoryKqRef, kCFFileDescriptorReadCallBack);
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
        id result = [[[MMParserContext alloc] init] parseString:textView.string];
        NSLog(@"Result: %@", result);

        MMAppDelegate *appDelegate = (MMAppDelegate *)[[NSApplication sharedApplication] delegate];
        MMTask *newTask = [MMTask new];
        newTask.command = [textView.string copy];
        newTask.startedAt = [NSDate date];
        [self.tasks addObject:newTask];
        [appDelegate runCommand:newTask.command];

        [textView setString:@""];
        self.commandHistoryIndex = self.tasks.count;

        [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(self.tasks.count - 1)] withAnimation:NSTableViewAnimationEffectNone];

        MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
        [self.window makeFirstResponder:lastController.outputView];

        CABasicAnimation *animation = [CABasicAnimation animation];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        animation.duration = 0.25;
        self.commandControlsLayoutConstraint.animations = @{@"constant": animation};

        [self.commandControlsLayoutConstraint.animator setConstant:20.0];

        return YES;
    } else if (commandSelector == @selector(scrollPageUp:)) {
        if (self.tasks.count > 0) {
            if (self.commandHistoryIndex == 0) {
                self.commandHistoryIndex = self.tasks.count;
            } else {
                self.commandHistoryIndex--;
            }
            NSString *commandToFill = self.commandHistoryIndex == self.tasks.count ? @"" : [(MMTask *)self.tasks[self.commandHistoryIndex] command];

            textView.string = commandToFill;
            return YES;
        }
    } else if (commandSelector == @selector(scrollPageDown:)) {
        if (self.tasks.count > 0) {
            if (self.commandHistoryIndex == self.tasks.count) {
                self.commandHistoryIndex = 0;
            } else {
                self.commandHistoryIndex++;
            }

            // When the user scrolls down past the last ran command, we fill the textbox with what they were typing.
            // TODO: Actually save what they were typing before they started scrolling.
            NSString *commandToFill = self.commandHistoryIndex == self.tasks.count ? @"" : [(MMTask *)self.tasks[self.commandHistoryIndex] command];

            textView.string = commandToFill;
            return YES;
        }
    } else if (commandSelector == @selector(insertTab:)) {
        [textView complete:self];
        return YES;
    }

    return NO;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
{
    // TODO: Handle tilde expansion.
    // TODO: Handle empty partial completion. (e.g. attempting a completion with "cd ")

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
