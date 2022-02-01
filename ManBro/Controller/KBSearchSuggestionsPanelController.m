//
//  KBDocumentControllerSuggestionsPanel.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import <os/log.h>

#import "KBPrefix.h"
#import "KBSection.h"
#import "KBDocumentMeta.h"
#import "KBSearchManager.h"
#import "NSURL+filesystem.h"
#import "NSObject+abstract.h"
#import "KBDocumentLoading.h"
#import "NSLayoutConstraint+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBSearchSuggestionsPanelController () <NSTableViewDataSource, NSTableViewDelegate> {
	__unsafe_unretained IBOutlet NSView *_scrollView;
	__unsafe_unretained IBOutlet NSTableView *_tableView;
	__unsafe_unretained IBOutlet NSTextField *_noDocumentsLabel;

	__unsafe_unretained IBOutlet NSLayoutConstraint *_maxWidthConstraint;
	__unsafe_unretained IBOutlet NSLayoutConstraint *_maxHeightConstraint;

	KBSearchManager *_searchManager;
	NSInteger _clickedRow;
}

@property (nonatomic, readonly) KBDocumentController *documentController;

@property (nonatomic, readonly, unsafe_unretained) NSView *scrollView;
@property (nonatomic, readonly, unsafe_unretained) NSTableView *tableView;
@property (nonatomic, readonly, unsafe_unretained) NSTextField *noDocumentsLabel;

@property (nonatomic, readonly, unsafe_unretained) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, readonly, unsafe_unretained) NSLayoutConstraint *maxHeightConstraint;

@property (nonatomic, copy) NSArray *tableViewItems;

@end

@implementation KBSearchSuggestionsPanelController

- (instancetype) init {
	return [self initWithWindowNibName:@"KBSearchSuggestionsPanelController"];
}

- (instancetype) initWithWindow: (NSWindow *) window {
	if (self = [super initWithWindow:window]) {
		_searchManager = [KBSearchManager new];
	}
	return self;
}

- (KBDocumentController *) documentController {
	return KB_DOWNCAST (KBDocumentController, self.window.parentWindow.windowController);
}

- (BOOL) isResizable {
	return YES;
}

- (NSSize) maxSize {
	return NSMakeSize (self.maxWidthConstraint.constant, self.maxHeightConstraint.constant);
}

- (void) setMaxSize: (NSSize) maxSize {
	self.maxWidthConstraint.constant = maxSize.width;
	self.maxHeightConstraint.constant = maxSize.height;
}

- (void) setQueryText: (NSString *) queryText {
	self.noDocumentsLabel.stringValue = NSLocalizedString (@"Searching…", nil);
	[_searchManager fetchDocumentsMatchingQuery:[[KBSearchQuery alloc] initWithText:queryText] completion:^(NSArray <id <NSFetchedResultsSectionInfo>> *documents) {
		self.documents = documents;
	}];
}

- (NSRange) visibleRows {
	return [self.tableView rowsInRect:self.tableView.visibleRect];
}

- (NSRange) fullyVisibleRows {
	NSRect const visibleRect = self.tableView.visibleRect;
	NSRange fullyVisibleRows = [self visibleRows];
	if (fullyVisibleRows.length && !NSContainsRect (visibleRect, [self.tableView rectOfRow:fullyVisibleRows.location])) {
		fullyVisibleRows.location++;
		fullyVisibleRows.length--;
	}
	if (fullyVisibleRows.length && !NSContainsRect (visibleRect, [self.tableView rectOfRow:NSMaxRange (fullyVisibleRows) - 1])) {
		fullyVisibleRows.length--;
	}
	return fullyVisibleRows;
}

- (BOOL) selectNextSuggestion {
	return [self selectAdjacentSuggestionSearchingBackward:NO];
}

- (BOOL) selectPrevSuggestion {
	return [self selectAdjacentSuggestionSearchingBackward:YES];
}

- (BOOL) selectAdjacentSuggestionSearchingBackward: (BOOL) searchBackwards {
	NSInteger row = self.tableView.selectedRow;
	if (row < 0) {
		row = searchBackwards ? -1 : 0;
	} else {
		searchBackwards ? row-- : row++;
	}
	return [self selectFirstSelectableRowStartingAt:row searchBackwards:searchBackwards];
}

- (BOOL) selectNextSuggestionsPage {
	{
		NSInteger const selectedRow = self.tableView.selectedRow;
		if (selectedRow < 0) { return [self selectFirstSuggestion]; }
		
		NSRange const visibleRows = [self fullyVisibleRows];
		if (NSMaxRange (visibleRows) == self.tableViewItems.count) {
			return [self selectFirstSelectableRowInRange:NSMaxRange (visibleRows) - 1 :MAX (visibleRows.location, selectedRow) searchBackwards:YES scrollToSelection:NO] || [self selectFirstSuggestion];
		}
	}
	{
		[self.scrollView pageDown:self];
		NSRange const visibleRows = [self visibleRows];
		[self selectFirstSelectableRowInRange:visibleRows.location : NSMaxRange (visibleRows) searchBackwards:NO];
		return YES;
	}
}

- (BOOL) selectPrevSuggestionsPage {
	{
		NSInteger const selectedRow = self.tableView.selectedRow;
		if (selectedRow < 0) { return [self selectLastSuggestion]; }
		
		NSRange const visibleRows = [self visibleRows];
		if ([self selectFirstSelectableRowInRange:visibleRows.location : MIN (NSMaxRange (visibleRows), selectedRow) searchBackwards:NO]) { return YES; }
		if (!visibleRows.location) { return [self selectLastSuggestion]; }
	}
	{
		[self.scrollView pageUp:self];
		NSRange const visibleRows = [self fullyVisibleRows];
		[self selectFirstSelectableRowInRange:visibleRows.location : NSMaxRange (visibleRows) searchBackwards:NO scrollToSelection:NO];
		[self.tableView scrollPoint:[self.tableView rectOfRow:visibleRows.location].origin];
		return YES;
	}
}

- (BOOL) selectFirstSuggestion {
	return [self selectFirstSelectableRowStartingAt:0 searchBackwards:NO];
}

- (BOOL) selectLastSuggestion {
	return [self selectFirstSelectableRowStartingAt:-1 searchBackwards:YES];
}

- (BOOL) selectFirstSelectableRowStartingAt: (NSInteger) firstRow searchBackwards: (BOOL) searchBackwards {
	return [self selectFirstSelectableRowStartingAt:firstRow searchBackwards:searchBackwards scrollToSelection:YES];
}

- (BOOL) selectFirstSelectableRowInRange: (NSInteger) firstRow : (NSInteger) lastRow searchBackwards: (BOOL) searchBackwards {
	return [self selectFirstSelectableRowInRange:firstRow :lastRow searchBackwards:searchBackwards scrollToSelection:YES];
}

- (BOOL) selectFirstSelectableRowStartingAt: (NSInteger) firstRow searchBackwards: (BOOL) searchBackwards scrollToSelection: (BOOL) scrollToSelection {
	return [self selectRow:[self firstSelectableRowStartingAt:firstRow searchBackwards:searchBackwards] scrollToSelection:scrollToSelection];
}

- (BOOL) selectFirstSelectableRowInRange: (NSInteger) firstRow : (NSInteger) lastRow searchBackwards: (BOOL) searchBackwards scrollToSelection: (BOOL) scrollToSelection {
	return [self selectRow:[self firstSelectableRowInRange:firstRow :lastRow searchBackwards:searchBackwards] scrollToSelection:scrollToSelection];
}

- (NSInteger) firstSelectableRowStartingAt: (NSInteger) firstRow searchBackwards: (BOOL) searchBackwards {
	return [self firstSelectableRowInRange:firstRow :NSNotFound searchBackwards:searchBackwards];
}

NS_INLINE NSInteger NSIntegerNormalizeModulo (NSInteger value, NSInteger modulus) {
	NSCParameterAssert (modulus > 0);
	return (value < 0) ? (modulus - -value % modulus) : value % modulus;
}

- (NSInteger) firstSelectableRowInRange: (NSInteger) firstRow : (NSInteger) lastRow searchBackwards: (BOOL) searchBackwards {
	if (firstRow == lastRow) { return NSNotFound; }
	NSInteger const itemsCount = self.tableViewItems.count;
	if (!itemsCount) { return NSNotFound; }

	NSInteger const rowStep = searchBackwards ? itemsCount - 1 : 1;
	firstRow = NSIntegerNormalizeModulo (firstRow, itemsCount);
	lastRow = (lastRow == NSNotFound) ? firstRow : NSIntegerNormalizeModulo (lastRow, itemsCount);
	NSInteger row = firstRow;
	do {
		if (![self tableView:self.tableView isGroupRow:row]) {
			return row;
		}
		row = (row + rowStep) % itemsCount;
	} while (row != lastRow);
	return NSNotFound;
}

- (BOOL) selectRow: (NSInteger) row scrollToSelection: (BOOL) scrollToSelection {
	if ((row == NSNotFound) || (row < 0) || (row >= self.tableViewItems.count)) { return NO; }
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	if (scrollToSelection) { (row > 1) ? [self.tableView scrollRowToVisible:row] : [self.tableView scrollPoint:NSZeroPoint]; }
	return YES;
}

- (BOOL) confirmSuggestionSelection {
	if (!self.tableViewItems.count) {
		return NO;
	}
	[self openDocument:self.tableViewItems [MAX (self.tableView.selectedRow, 1)]];
	return YES;
}

- (void) setDocuments: (NSArray <id <NSFetchedResultsSectionInfo>> *) documents {
	NSUInteger itemsCount = 0;
	for (id <NSFetchedResultsSectionInfo> section in documents) {
		NSUInteger const objectsCount = section.numberOfObjects;
		itemsCount += objectsCount ? objectsCount + 1 : 0;
	}
	
	NSManagedObjectContext *const context = [NSPersistentContainer sharedContainer].viewContext;
	NSMutableArray *tableViewItems = [[NSMutableArray alloc] initWithCapacity:itemsCount];
	for (id <NSFetchedResultsSectionInfo> section in documents) {
		if (!section.numberOfObjects) { continue; }
		[tableViewItems addObject:section];
		NSArray <NSManagedObjectID *> *const objectIDs = [section.objects valueForKey:@"objectID"];
		[context performBlockAndWait:^{
			for (NSManagedObjectID *objectID in objectIDs) {
				[tableViewItems addObject:[context objectWithID:objectID]];
			}
		}];
	}
	
	dispatch_async (dispatch_get_main_queue (), ^{
		NSManagedObjectID *selectedID = (self.tableView.selectedRow < 0) ? nil : [self.tableViewItems [self.tableView.selectedRow] objectID];
		self.tableViewItems = tableViewItems;
		
		[self.tableView reloadData];
		[self.tableViewItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			if ([obj isKindOfClass:[KBDocumentMeta class]] && [selectedID isEqual:[obj objectID]]) {
				*stop = YES;
				[self selectRow:idx scrollToSelection:YES];
			}
		}];
		
		self.noDocumentsLabel.hidden = !!tableViewItems.count;
		self.noDocumentsLabel.stringValue = NSLocalizedString (@"Nothing found", nil);
	});
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView {
	return self.tableViewItems.count;
}

- (BOOL) tableView: (NSTableView *) tableView isGroupRow: (NSInteger) row {
	return [self.tableViewItems [row] conformsToProtocol:@protocol (NSFetchedResultsSectionInfo)];
}

- (id) tableView: (NSTableView *) tableView objectValueForTableColumn: (NSTableColumn *) tableColumn row: (NSInteger) row {
	id const object = self.tableViewItems [row];
	if ([object isKindOfClass:[KBDocumentMeta class]]) {
		KBDocumentMeta *const doc = object;
		NSMutableAttributedString *const result = [[NSMutableAttributedString alloc] initWithString:doc.presentationTitle attributes:@{NSForegroundColorAttributeName: [NSColor controlTextColor]}];
		[result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\t"]];
		[result appendAttributedString:[[NSAttributedString alloc] initWithString:doc.URL.fileSystemPath attributes:@{NSForegroundColorAttributeName: [NSColor disabledControlTextColor]}]];
		return result;
	} else if ([object conformsToProtocol:@protocol (NSFetchedResultsSectionInfo)]) {
		return [object name];
	} else {
		os_log_t const logHandle = os_log_create ("KBDocumentControllerSuggestionsPanel", "NSTableViewDataSource");
		os_log_fault (logHandle, "Unexpected item: %@", object);
		abort ();
	}
}

- (BOOL) tableView: (NSTableView *) tableView shouldSelectRow: (NSInteger) row {
	return ![self tableView:tableView isGroupRow:row];
}

- (IBAction) tableViewCellClicked: (NSTableView *) sender {
	if (sender.clickedRow < 0) { return; }
	KBDocumentMeta *const document = self.tableViewItems [sender.clickedRow];
	if ([document isKindOfClass:[KBDocumentMeta class]]) {
		[self openDocument:document];
	}
}

- (void) openDocument: (KBDocumentMeta *) document {
	NSUInteger const targetIdentifier = (self.window.currentEvent.modifierFlags & NSEventModifierFlagCommand) ? 0 : self.documentController.identifier;
	[KBDocumentController openURL:[[NSURL alloc] initWithTargetURL:document.loaderURI sourceIdentifier:self.documentController.identifier targetIdentifier:targetIdentifier]];
	[self close];
}

@end
