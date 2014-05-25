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
#import "MMInfoOverlayView.h"
#import "MMInfoPanelController.h"
#import "MMRemoteTerminalConnection.h"

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

@property NSInteger numberOfTasksRunning;
@property BOOL hidingCommandInputControls;

@property CGFloat extraWidthMargin;
@property CGFloat extraHeightMargin;

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
  //self.window.restorationClass = [[NSApp delegate] class];

  self.extraWidthMargin = 46.0;
  self.extraHeightMargin = 335.0;

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

    if ([state containsValueForKey:MMSelfKey(extraWidthMargin)]) {
      self.extraWidthMargin = [state decodeFloatForKey:MMSelfKey(extraWidthMargin)];
      self.extraHeightMargin = [state decodeFloatForKey:MMSelfKey(extraHeightMargin)];
    }
  }

  // Set our terminal height and width correctly.
  [self windowDidResize:nil];

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

- (NSInteger)indexOfTask:(MMTaskCellViewController *)taskViewController;
{
  NSInteger i;
  for (i = self.taskViewControllers.count - 1; i >= 0 && ![self.taskViewControllers[i] isEqual:taskViewController]; i--);
  NSAssert(i >= 0, @"Must be able to find index for view controller");
  return i;
}

- (void)noteHeightChangeForTask:(MMTaskCellViewController *)taskViewController;
{
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] setDuration:0.0];
  [self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:[self indexOfTask:taskViewController]]];
  [NSAnimationContext endGrouping];
}

- (void)taskStarted:(MMTaskCellViewController *)taskController;
{
  self.numberOfTasksRunning++;

  [self hideCommandControlsIfNecessary];
}

- (void)taskFinished:(MMTaskCellViewController *)taskController;
{
  self.numberOfTasksRunning--;
  NSAssert(self.numberOfTasksRunning >= 0, @"Number of tasks cannot be negative");
  [self invalidateRestorableState];

  // If there are still tasks running, we make sure the running tasks stay at the bottom.
  if (self.numberOfTasksRunning > 0) {
    NSInteger oldIndex = [self indexOfTask:taskController];
    MMTask *task = self.tasks[oldIndex];
    [self.tasks removeObjectAtIndex:oldIndex];
    [self.taskViewControllers removeObjectAtIndex:oldIndex];

    NSInteger indexToMoveTask;
    NSInteger runningTasksSeen = 0;
    for (indexToMoveTask = self.taskViewControllers.count - 1; indexToMoveTask >= 0; indexToMoveTask--) {
      if (!((MMTask *)self.tasks[indexToMoveTask]).isFinished) {
        runningTasksSeen++;
      }

      if (runningTasksSeen == self.numberOfTasksRunning) {
        break;
      }
    }

    [self.tasks insertObject:task atIndex:indexToMoveTask];
    [self.taskViewControllers insertObject:taskController atIndex:indexToMoveTask];

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.0];
    [self.tableView reloadData];
    [self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(indexToMoveTask, self.tasks.count - indexToMoveTask)]];
    [NSAnimationContext endGrouping];
  }

  [self showCommandControlsIfNecessary];
}

- (void)taskRunsInBackground:(MMTaskCellViewController *)taskController;
{
  [self.terminalConnection startShellsToRunCommands:(self.numberOfTasksRunning + 1)];

  [self showCommandControlsIfNecessary];

  [[MMInfoPanelController sharedController] showPanel:@"SuspendControls"];
}

- (void)hideCommandControlsIfNecessary;
{
  if (self.hidingCommandInputControls) {
    return;
  }

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

  self.hidingCommandInputControls = YES;
}

- (void)showCommandControlsIfNecessary;
{
  [self.window makeFirstResponder:self.commandInput];

  if (!self.hidingCommandInputControls) {
    return;
  }

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

  self.hidingCommandInputControls = NO;
}

- (void)directoryChangedTo:(NSString *)newPath;
{
  self.currentDirectory = newPath;

  [self updateDirectoryView:newPath];
  [self updateTitle];
}

- (void)updateDirectoryView:(NSString *)directoryPath;
{
  [self.currentDirectoryLabel setStringValue:[NSString stringWithFormat:@"Current directory: %@", directoryPath]];

  NSDictionary *files = [self.terminalConnection dataForPath:directoryPath];
  NSMutableArray *directoryCollectionViewData = [NSMutableArray arrayWithCapacity:files.count];
  for (NSString *file in files) {
    NSImage *icon = [files[file] boolValue] ? [[NSWorkspace sharedWorkspace] iconForFile:@"/usr"] : [[NSWorkspace sharedWorkspace] iconForFileType:file.pathExtension];
    [directoryCollectionViewData addObject:
     @{
       @"name": file,
       @"icon": icon,
       }];

  }
  directoryCollectionViewData = [[directoryCollectionViewData sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name.lowercaseString" ascending:YES]]] mutableCopy];

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

- (NSInteger)indexOfSelectedRow;
{
  if (![self.window.firstResponder isKindOfClass:[MMTextView class]]) {
    return -1;
  }
  NSView *view = (NSView *)self.window.firstResponder;
  while (![view isKindOfClass:[NSTableRowView class]]) {
    view = view.superview;
  }
  view = view.subviews[0];

  NSInteger i;
  for (i = self.taskViewControllers.count - 1; i >= 0; i--) {
    if ([[self.taskViewControllers[i] view] isEqual:view]) {
      break;
    }
  }

  return i;
}

- (IBAction)selectPreviousCommand:(id)sender;
{
  NSInteger currentCommand = [self indexOfSelectedRow];
  if (currentCommand != -1 &&
      currentCommand > 0 &&
      ![self.taskViewControllers[currentCommand - 1] task].isFinished) {
    [self.window makeFirstResponder:((MMTaskCellViewController *)self.taskViewControllers[currentCommand - 1]).outputView];
  } else if (![self.taskViewControllers.lastObject task].isFinished) {
    [self.window makeFirstResponder:((MMTaskCellViewController *)self.taskViewControllers.lastObject).outputView];
  }
}

- (IBAction)selectNextCommand:(id)sender;
{
  NSInteger currentCommand = [self indexOfSelectedRow];
  if (currentCommand != -1 &&
      currentCommand < self.taskViewControllers.count - 1 &&
      ![self.taskViewControllers[currentCommand + 1] task].isFinished) {
    [self.window makeFirstResponder:((MMTaskCellViewController *)self.taskViewControllers[currentCommand + 1]).outputView];
  } else if (![self.taskViewControllers.lastObject task].isFinished) {
    [self.window makeFirstResponder:((MMTaskCellViewController *)self.taskViewControllers.lastObject).outputView];
  }
}

- (BOOL)isRemoteConnection;
{
  return [[self.terminalConnection class] isSubclassOfClass:[MMRemoteTerminalConnection class]];
}

# pragma mark - Directory watching

- (void)directoryModified:(NSString *)path;
{
  if ([self.currentDirectory isEqualToString:path]) {
    [self updateDirectoryView:path];
  }
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
  if (self.hidingCommandInputControls) {
    MMTaskCellViewController *lastController = self.taskViewControllers.lastObject;
    [self.window makeFirstResponder:lastController.outputView];
  }
  return !self.hidingCommandInputControls;
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector;
{
  if (commandSelector == @selector(insertNewline:)) {
    MMTaskCellViewController *taskViewController = [[MMTaskCellViewController alloc] init];
    MMTask *task = [self.terminalConnection createAndRunTaskWithCommand:textView.string taskDelegate:taskViewController];

    if (!task) {
      return YES;
    }

    NSInteger taskIndex = self.tasks.count;
    [self.tasks addObject:task];
    [self.taskViewControllers addObject:taskViewController];

    [textView setString:@""];
    self.commandHistoryIndex = taskIndex + 1;

    [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:taskIndex] withAnimation:NSTableViewAnimationEffectNone];

    [self.window makeFirstResponder:taskViewController.outputView];

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
  return [(MMTaskCellViewController *)self.taskViewControllers[row] heightToFitAllOfOutput];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
{
  return [self.taskViewControllers[row] view];
}

- (void)_prepareViewControllersUntilRow:(NSInteger)row;
{
  for (NSInteger i = [self.taskViewControllers count]; i <= row; i++) {
    MMTaskCellViewController *taskViewController = [[MMTaskCellViewController alloc] init];
    taskViewController.task = self.tasks[i];
    [self.taskViewControllers addObject:taskViewController];
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
  // In terms of height considerations:
  // 15 is added for each row of text and (by default) we add 335 for the surrounding chrome/context.
  // The 335 value is a margin that is modifiable by the user, by resizing and holding down Command.

  if ([NSEvent modifierFlags] & NSCommandKeyMask) {
    self.extraHeightMargin = frameSize.height - (15 * self.terminalConnection.terminalHeight);
  }

  NSSize newFrame = frameSize;
  NSInteger columns = MAX(20, [MMTextView columnsForWidthOfText:(frameSize.width - self.extraWidthMargin)]);
  NSInteger rows = MAX(10, round((frameSize.height - self.extraHeightMargin) / 15));

  self.infoOverlayView.displayText = [NSString stringWithFormat:@"%ldx%ld", columns, rows];

  newFrame.width = ceil(self.extraWidthMargin + [MMTextView widthForColumnsOfText:columns]);
  newFrame.height = floor(self.extraHeightMargin + rows * 15);
  return newFrame;
}

- (void)resizeWindowForTerminalScreenSizeOfColumns:(NSInteger)columns rows:(NSInteger)rows;
{
  CGSize newSize = self.window.frame.size;
  newSize.width = ceil([MMTextView widthForColumnsOfText:columns]) + self.extraWidthMargin;
  newSize.height = 15 * rows + self.extraHeightMargin;
  NSRect newFrame = self.window.frame;
  newFrame.size = newSize;

  [self.window setFrame:newFrame display:YES];
}

- (void)windowDidResize:(NSNotification *)notification;
{
  NSInteger newWidth = [MMTextView columnsForWidthOfText:(self.window.frame.size.width - self.extraWidthMargin)];
  NSInteger newHeight = lround((self.window.frame.size.height - self.extraHeightMargin) / 15);

  [self.terminalConnection changeTerminalSizeToColumns:newWidth rows:newHeight];
  // TODO: Affect all active tasks.
  [[self.taskViewControllers lastObject] resizeTerminalToColumns:newWidth rows:newHeight];
}

- (void)windowWillClose:(NSNotification *)notification;
{
  MMAppDelegate *appDelegate = [NSApp delegate];
  [appDelegate terminalWindowWillClose:self];
}

# pragma mark - NSWindowRestoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder;
{
  [coder encodeObject:self.tasks forKey:MMSelfKey(tasks)];
  [coder encodeObject:self.currentDirectory forKey:MMSelfKey(currentDirectory)];
  [coder encodeInteger:self.terminalConnection.terminalHeight forKey:@"terminalHeight"];
  [coder encodeInteger:self.terminalConnection.terminalWidth forKey:@"terminalWidth"];
  [coder encodeFloat:self.extraWidthMargin forKey:MMSelfKey(extraWidthMargin)];
  [coder encodeFloat:self.extraHeightMargin forKey:MMSelfKey(extraHeightMargin)];
}

@end
