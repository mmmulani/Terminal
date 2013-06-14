//
//  MMTerminalWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#include <sys/event.h>

#import "MMTerminalWindowController.h"
#import "MMShared.h"
#import "MMTask.h"
#import "MMTaskCellViewController.h"
#import "MMTerminalConnection.h"
#import "MMCompletionEngine.h"
#import "MMCommandsTextView.h"
#import "MMAppDelegate.h"
#import "MMUtilities.h"
#import "MMInfoOverlayView.h"

#import <tgmath.h>
#import <QuartzCore/QuartzCore.h>

@interface MMTerminalWindowController ()

// An index into |self.tasks| of the current task shown in the command input field.
@property NSUInteger commandHistoryIndex;
@property NSString *currentDirectory;

@property CGFloat originalCommandControlsLayoutConstraintConstant;

@property NSMutableDictionary *directoriesBeingWatched;
@property CFFileDescriptorRef directoryKqRef;

@property NSInteger keyboardShortcut;

@end

@implementation MMTerminalWindowController

- (id)initWithTerminalConnection:(MMTerminalConnection *)terminalConnection withState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;
{
    self = [self initWithWindowNibName:@"MMTerminalWindow"];

    self.tasks = [NSMutableArray array];
    self.taskViewControllers = [NSMutableArray array];
    self.commandHistoryIndex = 0;
    self.directoriesBeingWatched = [NSMutableDictionary dictionary];
    self.terminalConnection = terminalConnection;
    self.window.restorationClass = [[NSApp delegate] class];

    if (state) {
        self.tasks = [state decodeObjectForKey:MMSelfKey(tasks)];
        if (!self.tasks) {
            self.tasks = [NSMutableArray array];
        }
        [self _prepareViewControllersUntilRow:(self.tasks.count - 1)];
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.0];
        [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tasks.count)] withAnimation:NSTableViewAnimationEffectNone];
        [self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tasks.count)]];
        [NSAnimationContext endGrouping];

        NSInteger terminalWidth = [state decodeIntegerForKey:@"terminalWidth"];
        NSInteger terminalHeight = [state decodeIntegerForKey:@"terminalHeight"];
        if (terminalWidth > 0) {
            self.terminalConnection.terminalWidth = terminalWidth;
            self.terminalConnection.terminalHeight = terminalHeight;
        }
    }

    return self;
}

- (void)awakeFromNib;
{
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminalOutputFrameChanged:) name:NSViewFrameDidChangeNotification object:self.tableView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminalOutputFrameChanged:) name:NSViewFrameDidChangeNotification object:self.tableView.superview];

    self.originalCommandControlsLayoutConstraintConstant = self.commandControlsLayoutConstraint.constant;
    self.commandInput.font = [NSFont systemFontOfSize:13.0];
    self.commandInput.completionEngine.terminalConnection = self.terminalConnection;

    MMAppDelegate *appDelegate = [NSApp delegate];
    self.keyboardShortcut = [appDelegate uniqueWindowShortcut];
    // Though we have assigned a keyboard shortcut, we have not updated the MainMenu with it.
    // Since we are required to update the MainMenu with keyboard shortcuts after the title changes, we set it in |updateTitle|.

    [self.window makeFirstResponder:self.commandInput];

    [self invalidateRestorableState];
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)terminalOutputFrameChanged:(NSNotification *)notification;
{
    // TODO: Add a check to see if we are already scrolled to the bottom, and only scroll down then.
    NSRect clipViewFrame = self.tableView.superview.frame;
    [((NSClipView *)self.tableView.superview) scrollToPoint:NSMakePoint(0, MAX(self.tableView.frame.size.height - clipViewFrame.size.height, 0))];
}

- (void)handleOutput:(NSString *)message;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        MMTask *lastTask = [self.tasks lastObject];
        [lastTask.displayTextStorage beginEditing];
        @try {
            [lastTask handleCommandOutput:message];
        }
        @catch (NSException *exception) {
            // Send the last 50KB of the output to our servers and then crash.
            NSData *dataToSend = [[lastTask.output substringFromIndex:MAX(0, (NSInteger)lastTask.output.length - (50 * 1024))] dataUsingEncoding:NSUTF8StringEncoding];
            NSURL *url = [NSURL URLWithString:@"http://crashy.mehdi.is/blobs/post.php"];
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            NSString *filename = [NSString stringWithFormat:@"%@_%@", infoDictionary[(NSString *)kCFBundleIdentifierKey], infoDictionary[(NSString *)kCFBundleVersionKey]];
            [MMUtilities postData:dataToSend toURL:url description:filename];
            @throw exception;
        }
        [lastTask.displayTextStorage endEditing];

        if ([self.taskViewControllers count] == [self.tasks count]) {
            // Force the outputView to re-layout its text and then resize it accordingly.
            MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
            [lastController updateWithANSIOutput];

            [lastController.outputView.layoutManager ensureLayoutForCharacterRange:NSMakeRange(0, lastController.outputView.string.length)];

            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:0.0];
            [self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:([self.taskViewControllers count] - 1)]];
            [NSAnimationContext endGrouping];
        }
    });
}

- (void)shellCommandFinished;
{
    [(MMTaskCellViewController *)[self.taskViewControllers lastObject] updateViewForShellCommand];
    [self processFinished:MMProcessStatusExit data:nil];
}

- (MMTask *)lastTask;
{
    return [self.tasks lastObject];
}

- (void)processFinished:(MMProcessStatus)status data:(id)data;
{
    MMTask *task = [self.tasks lastObject];
    [task processFinished:status data:data];
    self.running = NO;

    MMTaskCellViewController *controller = [self.taskViewControllers lastObject];
    [controller updateWithANSIOutput];

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.0];
    [self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:([self.taskViewControllers count] - 1)]];
    [NSAnimationContext endGrouping];

    [self.window makeFirstResponder:self.commandInput];

    [NSAnimationContext beginGrouping];
    CABasicAnimation *animation = [CABasicAnimation animation];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    animation.duration = 0.25;
    self.commandControlsLayoutConstraint.animations = @{@"constant": animation};
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [self.window.contentView layout];
    }];

    [self.commandControlsLayoutConstraint.animator setConstant:self.originalCommandControlsLayoutConstraintConstant];
    [NSAnimationContext endGrouping];

    [self invalidateRestorableState];
}

- (void)directoryChangedTo:(NSString *)newPath;
{
    if (self.currentDirectory) {
        [self unregisterDirectory:self.currentDirectory];
    }
    self.currentDirectory = newPath;
    [self registerDirectoryToBeObserved:newPath];

    [self updateDirectoryView:newPath];
    [self updateTitle];
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

- (void)updateTitle;
{
    NSString *title;
    if (self.keyboardShortcut != -1) {
        title = [NSString stringWithFormat:@"%@ — ⌘%ld", [self.currentDirectory stringByAbbreviatingWithTildeInPath], self.keyboardShortcut];
    } else {
        title = [self.currentDirectory stringByAbbreviatingWithTildeInPath];
    }

    self.window.title = title;

    // Changing the title resets the window shortcut, so we must reassign it.
    MMAppDelegate *appDelegate = [NSApp delegate];
    [appDelegate updateWindowMenu];
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

# pragma mark - NSTextDelegate

- (BOOL)textShouldBeginEditing:(NSText *)fieldEditor;
{
    if (self.running) {
        MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
        [self.window makeFirstResponder:lastController.outputView];
    }
    return !self.running;
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector;
{
    if (commandSelector == @selector(insertNewline:)) {
        [self.tasks addObject:[self.terminalConnection createAndRunTaskWithCommand:textView.string]];

        [textView setString:@""];
        self.commandHistoryIndex = self.tasks.count;

        [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(self.tasks.count - 1)] withAnimation:NSTableViewAnimationEffectNone];

        MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
        [self.window makeFirstResponder:lastController.outputView];

        [NSAnimationContext beginGrouping];
        CABasicAnimation *animation = [CABasicAnimation animation];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        animation.duration = 0.25;
        self.commandControlsLayoutConstraint.animations = @{@"constant": animation};
        [[NSAnimationContext currentContext] setCompletionHandler:^{
            [self.window.contentView layout];
        }];

        [self.commandControlsLayoutConstraint.animator setConstant:0.0];
        [NSAnimationContext endGrouping];

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

# pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [self.tasks count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row;
{
    [self _prepareViewControllersUntilRow:row];
    return [(MMTaskCellViewController *)self.taskViewControllers[row] heightToFitAllOfOutput];
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

# pragma mark - NSWindowDelegate

- (void)windowWillStartLiveResize:(NSNotification *)notification;
{
    self.infoOverlayView.alphaValue = 1.0;
}

- (void)windowDidEndLiveResize:(NSNotification *)notification;
{
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.75];
    [self.infoOverlayView.animator setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize;
{
    // In terms of width considerations:
    // 7.82666 is required for each column and 56 is required for the surrounding chrome.
    // For height:
    // 15 is required for each row and 337 is required for the chrome.

    NSSize newFrame = frameSize;
    NSInteger columns = MAX(20, round((frameSize.width - 56) / 7.82666));
    NSInteger rows = MAX(10, round((frameSize.height - 337) / 15));

    self.infoOverlayView.displayText = [NSString stringWithFormat:@"%ldx%ld", columns, rows];

    newFrame.width = floor(56 + columns * 7.82666);
    newFrame.height = floor(337 + rows * 15);
    return newFrame;
}

- (void)resizeWindowForTerminalScreenSizeOfColumns:(NSInteger)columns rows:(NSInteger)rows;
{
    CGSize newSize = self.window.frame.size;
    newSize.width = round(7.82666 * columns) + 56;
    newSize.height = 15 * rows + 337;
    NSRect newFrame = self.window.frame;
    newFrame.size = newSize;

    [self.window setFrame:newFrame display:YES];
}

- (void)windowDidResize:(NSNotification *)notification;
{
    NSInteger newWidth = lround((self.window.frame.size.width - 56) / 7.82666);
    NSInteger newHeight = lround((self.window.frame.size.height - 337) / 15);

    [self.terminalConnection changeTerminalSizeToColumns:newWidth rows:newHeight];
    [[self.taskViewControllers lastObject] resizeTerminalToColumns:newWidth rows:newHeight];
}

- (void)windowWillClose:(NSNotification *)notification;
{
    MMAppDelegate *appDelegate = [NSApp delegate];
    [appDelegate terminalWindowWillClose:self];
    if (self.currentDirectory) {
        [self unregisterDirectory:self.currentDirectory];
    }
}

# pragma mark - NSWindowRestoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder;
{
    [coder encodeObject:self.tasks forKey:MMSelfKey(tasks)];
    [coder encodeObject:self.currentDirectory forKey:MMSelfKey(currentDirectory)];
    [coder encodeInteger:self.terminalConnection.terminalHeight forKey:@"terminalHeight"];
    [coder encodeInteger:self.terminalConnection.terminalWidth forKey:@"terminalWidth"];
}

@end
