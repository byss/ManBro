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
#import "NSLayoutConstraint+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentControllerSuggestionsPanel () <NSTableViewDataSource, NSTableViewDelegate> {
	KBSearchManager *_searchManager;
	NSInteger _clickedRow;
}

@property (nonatomic, readonly, unsafe_unretained) NSView *scrollView;
@property (nonatomic, readonly, unsafe_unretained) NSTableView *tableView;
@property (nonatomic, readonly, unsafe_unretained) NSView *noDocumentsView;

@property (nonatomic, readonly, unsafe_unretained) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, readonly, unsafe_unretained) NSLayoutConstraint *maxHeightConstraint;
@property (nonatomic, readonly, unsafe_unretained) NSLayoutConstraint *tableWidthConstraint;

@property (nonatomic, copy) NSArray *tableViewItems;

@end

@implementation KBDocumentControllerSuggestionsPanel

- (instancetype) initWithContentRect: (NSRect) contentRect styleMask: (NSWindowStyleMask) style backing: (NSBackingStoreType) backingStoreType defer: (BOOL) flag {
	style = NSWindowStyleMaskBorderless | NSWindowStyleMaskTitled | NSWindowStyleMaskDocModalWindow | NSWindowStyleMaskNonactivatingPanel | NSWindowStyleMaskFullSizeContentView;
	if (self = [super initWithContentRect:contentRect styleMask:style backing:backingStoreType defer:flag]) {
		self.titleVisibility = NSWindowTitleHidden;
		self.titlebarAppearsTransparent = YES;
		self.floatingPanel = YES;
		self.becomesKeyOnlyIfNeeded = YES;
		self.level = NSModalPanelWindowLevel;
		self.movable = NO;
		self.releasedWhenClosed = NO;
		self.worksWhenModal = YES;
		
		_searchManager = [[KBSearchManager alloc] initWithContext:[NSPersistentContainer sharedContainer].viewContext];
		
		NSRect const contentBounds = NSOffsetRect (contentRect, -NSMinX (contentRect), -NSMinY (contentRect));
		
		NSTableColumn *const column = [NSTableColumn new];
		column.editable = NO;
		column.resizingMask = NSTableColumnAutoresizingMask;
		column.width = column.minWidth = 100.0;

		NSTableView *tableView = [[NSTableView alloc] initWithFrame:contentBounds];
		tableView.translatesAutoresizingMaskIntoConstraints = NO;
		tableView.headerView = nil;
		tableView.backgroundColor = [NSColor clearColor];
		[tableView addTableColumn:column];
		tableView.dataSource = self;
		tableView.delegate = self;
		_tableView = tableView;
		_clickedRow = -1;
		
		NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:contentBounds];
		scrollView.translatesAutoresizingMaskIntoConstraints = NO;
		scrollView.hidden = YES;
		scrollView.automaticallyAdjustsContentInsets = NO;
		scrollView.hasVerticalScroller = YES;
		scrollView.drawsBackground = NO;
		scrollView.contentView.translatesAutoresizingMaskIntoConstraints = NO;
		scrollView.documentView = tableView;
		_scrollView = scrollView;
		
		NSView *noDocumentsView = [[NSView alloc] initWithFrame:contentBounds];
		noDocumentsView.translatesAutoresizingMaskIntoConstraints = NO;
		
		NSTextField *noDocumentsLabel = [NSTextField new];
		noDocumentsLabel.translatesAutoresizingMaskIntoConstraints = NO;
		noDocumentsLabel.stringValue = @"Nothing found";
		noDocumentsLabel.editable = NO;
		noDocumentsLabel.backgroundColor = [NSColor windowBackgroundColor];
		noDocumentsLabel.bordered = NO;
		[noDocumentsLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[noDocumentsLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
		[noDocumentsLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[noDocumentsLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
		[noDocumentsLabel sizeToFit];
		[noDocumentsView addSubview:noDocumentsLabel];
		_noDocumentsView = noDocumentsView;
		
		NSView *contentView = [[NSView alloc] initWithFrame:contentBounds];
		contentView.translatesAutoresizingMaskIntoConstraints = NO;
		[contentView addSubview:scrollView];
		[contentView addSubview:noDocumentsView];
		self.contentView = contentView;
		
		NSLayoutConstraint *const maxWidthConstraint = [contentView.widthAnchor constraintLessThanOrEqualToConstant:contentRect.size.width];
		NSLayoutConstraint *const maxHeightConstraint = [contentView.heightAnchor constraintLessThanOrEqualToConstant:contentRect.size.height];
		NSLayoutConstraint *const tableWidthConstraint = [tableView.widthAnchor constraintEqualToConstant:column.minWidth priority:NSLayoutPriorityDefaultHigh];

		[NSLayoutConstraint activateAllConstraintsFrom:
			maxWidthConstraint, maxHeightConstraint, tableWidthConstraint,
		 
			[scrollView constrainBoundsToSuperviewBounds],
			[scrollView.contentView constrainBoundsToSuperviewBounds],
			[tableView constrainBoundsToSuperviewBounds],
		
			[scrollView.heightAnchor constraintEqualToAnchor:tableView.heightAnchor priority:NSLayoutPriorityDefaultHigh],
			
			[scrollView.widthAnchor constraintEqualToAnchor:contentView.widthAnchor],
			[scrollView.contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
			[tableView.widthAnchor constraintLessThanOrEqualToAnchor:scrollView.contentView.widthAnchor],

			[noDocumentsView constrainBoundsToSuperviewBounds],
			[noDocumentsView.widthAnchor constraintEqualToConstant:0.0 priority:NSLayoutPriorityAlmostIgnored],

			[noDocumentsLabel constrainCenterToSuperviewCenter],
			[noDocumentsLabel.leadingAnchor constraintGreaterThanOrEqualToSystemSpacingAfterAnchor:noDocumentsView.leadingAnchor multiplier:1.0],
			[noDocumentsLabel.topAnchor constraintGreaterThanOrEqualToSystemSpacingBelowAnchor:noDocumentsView.topAnchor multiplier:1.0],
		 
			nil
		];
		_maxWidthConstraint = maxWidthConstraint;
		_maxHeightConstraint = maxHeightConstraint;
		_tableWidthConstraint = tableWidthConstraint;
	}
	return self;
}

- (BOOL) isResizable {
	return YES;
}

- (void) setMaxSize: (NSSize) maxSize {
	[super setMaxSize:maxSize];
	self.maxWidthConstraint.constant = maxSize.width;
	self.maxHeightConstraint.constant = maxSize.height;
}

- (void) setQueryText: (NSString *) queryText {
	[_searchManager fetchDocumentsMatchingQuery:[[KBSearchQuery alloc] initWithText:queryText] completion:^(NSArray <id <NSFetchedResultsSectionInfo>> *documents) {
		[self setDocuments:documents];
	}];
}

- (BOOL) selectNextSuggestion {
	[self selectSuggestionWithOffset:1];
	return YES;
}

- (BOOL) selectPrevSuggestion {
	[self selectSuggestionWithOffset:-1];
	return YES;
}

- (void) selectSuggestionWithOffset: (NSInteger) offset {
	if (!self.tableViewItems.count) {
		return;
	}
	NSInteger rowToSelect;
	if (self.tableView.selectedRow < 0) {
		rowToSelect = (offset > 0) ? 1 : self.tableViewItems.count - 1;
	} else {
		rowToSelect = self.tableView.selectedRow;
		do {
			rowToSelect = (rowToSelect + offset) % self.tableViewItems.count;
		} while ([self tableView:self.tableView isGroupRow:rowToSelect]);
	}
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelect] byExtendingSelection:NO];
}

- (BOOL) confirmSuggestionSelection {
	if (!self.tableViewItems.count) {
		return NO;
	}
	KBDocumentMeta *doc = self.tableViewItems [MAX (self.tableView.selectedRow, 1)];
	[self.navigationDelegate searchPanel:self didRequestDocument:doc options:KBReplaceCurrentContext];
	return YES;
}

- (void) setDocuments: (NSArray <id <NSFetchedResultsSectionInfo>> *) documents {
	NSManagedObjectID *selectedID = (self.tableView.selectedRow < 0) ? nil : [self.tableViewItems [self.tableView.selectedRow] objectID];
	
	NSUInteger itemsCount = 0;
	for (id <NSFetchedResultsSectionInfo> section in documents) {
		NSUInteger const objectsCount = section.numberOfObjects;
		itemsCount += objectsCount ? objectsCount + 1 : 0;
	}
	NSMutableArray *tableViewItems = [[NSMutableArray alloc] initWithCapacity:itemsCount];
	for (id <NSFetchedResultsSectionInfo> section in documents) {
		if (!section.numberOfObjects) { continue; }
		[tableViewItems addObject:section];
		[tableViewItems addObjectsFromArray:section.objects];
	}
	self.tableViewItems = tableViewItems;

	[self.tableView reloadData];
	
	NSTableColumn *const column = self.tableView.tableColumns.firstObject;
	CGFloat maxWidth = column.minWidth;
	NSRange const visibleRows = [self.tableView rowsInRect:self.tableView.visibleRect];
	for (NSUInteger row = visibleRows.location; row < NSMaxRange (visibleRows); row++) {
		maxWidth = MAX (maxWidth, [self ceilValue:[[column dataCellForRow:row] cellSize].width]);
	}
	self.tableWidthConstraint.constant = maxWidth;

	[self.tableViewItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if ([obj isKindOfClass:[KBDocumentMeta class]] && [selectedID isEqual:[obj objectID]]) {
			*stop = YES;
			[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
		}
	}];
	self.noDocumentsView.hidden = !(self.scrollView.hidden = !tableViewItems.count);
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
		return [[NSString alloc] initWithFormat:@"%@ (%@) – %s", doc.title, doc.section.name, doc.URL.fileSystemRepresentation];
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

- (void) tableViewSelectionIsChanging: (NSNotification *) notification {
	if (self.currentEvent.type == NSEventTypeLeftMouseDown) {
		_clickedRow = [self.tableView rowAtPoint:[self.tableView convertPoint:self.currentEvent.locationInWindow fromView:nil]];
	} else {
		_clickedRow = -1;
	}
}

- (void) tableView: (NSTableView *) tableView willDisplayCell: (id) cell forTableColumn: (NSTableColumn *) tableColumn row: (NSInteger) row {
	self.tableWidthConstraint.constant = MAX (self.tableWidthConstraint.constant, [self ceilValue:[cell cellSize].width]);
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification {
	if (_clickedRow == self.tableView.selectedRow) {
		[self confirmSuggestionSelection];
		_clickedRow = -1;
	}
}

@end
