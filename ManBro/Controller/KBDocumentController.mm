//
//  KBDocumentController.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import <unordered_map>
#import <unordered_set>

#import "KBSection.h"
#import "KBDocumentMeta.h"
#import "NSURL+filesystem.h"
#import "NSObject+abstract.h"
#import "NSObject+blockKVO.h"
#import "KBDocumentLoading.h"
#import "NSLayoutConstraint+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"

@implementation NSViewController (KBDocumentController)

- (KBDocumentController *) documentController {
	if (![self conformsToProtocol:@protocol (KBDocumentController)]) { return nil; }
	return KB_DOWNCAST (KBDocumentController, self.view.window.windowController);
}

@end

@interface KBDocumentControllerIndexUpdateIndicatorController: NSTitlebarAccessoryViewController
@end

@interface KBDocumentController (searchSuggestionsPanelManagement)

- (void) setSearchSheetHidden: (BOOL) searchSheetHidden;
- (void) setSearchSheetQueryText: (NSString *) queryText;
- (void) updateDocumentsSuggestionsPanelPosition;

@end

@interface KBDocumentController (NSWindowRestoration) <NSWindowRestoration>
@end
@interface KBDocumentController (NSSearchFieldDelegate) <NSSearchFieldDelegate>
@end

template <typename _Tp>
NS_INLINE _Tp arc4random_value () {
	_Tp result;
	arc4random_buf (&result, sizeof (result));
	return result;
}

template <typename _Tp>
NS_INLINE _Tp &arc4random_value (_Tp &result) {
	return result = arc4random_value <_Tp> ();
}

@interface KBDocumentController () {
	__unsafe_unretained id _indexUpdateIndicator;
	__unsafe_unretained IBOutlet NSToolbarItem *_tocItem;
	__unsafe_unretained IBOutlet NSSearchToolbarItem *_searchItem;
}

@property (nonatomic, unsafe_unretained, readonly) NSToolbarItem *tocItem;
@property (nonatomic, unsafe_unretained, readonly) NSSearchToolbarItem *searchItem;
@property (nonatomic, strong) KBSearchSuggestionsPanelController *searchSuggestionsPanelController;
@property (nonatomic, readonly) NSSearchField *searchField;

@end

@implementation KBDocumentController

@dynamic contentViewController, currentDocument, tocController, contentController;

static NSString *const KBDocumentControllerClassName = @"KBDocumentController";
static void *const KBDocumentControllerObservationContext = arc4random_value <void *> ();
static std::unordered_map <NSUInteger, KBDocumentController *> KBDocumentControllerInstances { { 0, nil } };

+ (void) load {
	if (self != [KBDocumentController class]) { return; }
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		KBDocumentControllerIndexManager *const indexMgr = [KBDocumentControllerIndexManager sharedManager];
		NSNotificationCenter *const center = [NSNotificationCenter defaultCenter];
		[center addObserver:indexMgr selector:@selector (updateIndexIfNeeded) name:NSApplicationDidFinishLaunchingNotification object:nil];
		[center addObserver:indexMgr selector:@selector (updateIndexIfNeeded) name:NSApplicationDidBecomeActiveNotification object:nil];
	});
}

+ (NSSet <NSString *> *) keyPathsForValuesAffectingCurrentDocument {
	static NSSet *keyPathsForValuesAffectingCurrentDocument;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{ keyPathsForValuesAffectingCurrentDocument = [[NSSet alloc] initWithObjects:@"contentViewController.currentDocument", nil] ;});
	return keyPathsForValuesAffectingCurrentDocument;
}

+ (KBDocumentController *__nullable) documentControllerWithIdentifier: (NSUInteger) identifier {
	auto const it = KBDocumentControllerInstances.find (identifier);
	return (it != KBDocumentControllerInstances.end ()) ? it->second : nil;
}

+ (id) forwardingTargetForSelector: (SEL) aSelector {
	if ((aSelector == @selector (canOpenURL:)) || (aSelector == @selector (openURL:))) {
		return [KBDocumentContentController class];
	} else {
		return [super forwardingTargetForSelector:aSelector];
	}
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype) init {
	return [[NSStoryboard storyboardWithName:KBDocumentControllerClassName bundle:nil] instantiateInitialController];
}

#pragma clang diagnostic pop

- (instancetype) initWithWindow: (NSWindow *) window {
	return [super initWithWindow:window];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
	return [super initWithCoder:coder];
}

- (instancetype) initWithWindowNibName: (NSNibName) windowNibName KB_ABSTRACT;
- (instancetype) initWithWindowNibName: (NSNibName) windowNibName owner: (id) owner KB_ABSTRACT;
- (instancetype) initWithWindowNibPath: (NSString *) windowNibPath owner: (id) owner KB_ABSTRACT;

- (id) forwardingTargetForSelector: (SEL) aSelector {
	static std::unordered_set <SEL> const contentViewControllerSelectors = {
		@selector (currentDocument), @selector (setCurrentDocument:),
		@selector (contentController), @selector (tocController),
	};
	if (contentViewControllerSelectors.contains (aSelector)) {
		return self.contentViewController;
	} else {
		return [super forwardingTargetForSelector:aSelector];
	}
}

- (void) windowDidLoad {
	[super windowDidLoad];

	self.window.restorable = YES;
	self.window.restorationClass = self.class;

	while (!KBDocumentControllerInstances.try_emplace (arc4random_value (_identifier), self).second);
	__unsafe_unretained typeof (self) unsafeSelf = self;
	[self observeObject:self keyPath:@"currentDocument" usingBlock:^{ [unsafeSelf currentDocumentDidChange]; }];
	[self observeObject:self.contentViewController.tocItem keyPath:@"collapsed" usingBlock:^{
		unsafeSelf.tocItem.toolbar.selectedItemIdentifier = unsafeSelf.contentViewController.tocItem.collapsed ? nil : unsafeSelf.tocItem.itemIdentifier;
	}];
	
	if ([KBDocumentControllerIndexManager sharedManager].updating) {
		[self addIndexUpdateProgressController];
	}
	
	NSNotificationCenter *const center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector (addIndexUpdateProgressController) name:KBDocumentControllerIndexManagerDidStartIndexUpdate object:nil];
	[center addObserver:self selector:@selector (removeIndexUpdateProgressController) name:KBDocumentControllerIndexManagerDidFinishIndexUpdate object:nil];
}

- (void) windowWillClose: (NSNotification *) notification {
	KBDocumentControllerInstances.erase (self.identifier);
}

- (void) windowDidMove: (NSNotification *) notification {
	[self updateDocumentsSuggestionsPanelPosition];
}

- (void) windowDidResize: (NSNotification *) notification {
	[self updateDocumentsSuggestionsPanelPosition];
}

- (void) currentDocumentDidChange {
	KBDocumentMeta *const document = self.currentDocument;
	NSURL *const documentURL = document.URL;
	NSWindow *const window = self.window;
	window.title = document.presentationTitle ?: NSLocalizedString (@"Loading…", nil);
	window.representedURL = documentURL;
	window.tab.toolTip = documentURL.fileSystemPath;
	[window.toolbar validateVisibleItems];
}

- (NSSearchField *) searchField {
	return self.searchItem.searchField;
}

- (void) addIndexUpdateProgressController {
	if (_indexUpdateIndicator) { return; }
	NSTitlebarAccessoryViewController *const indexUpdateIndicator = [KBDocumentControllerIndexUpdateIndicatorController new];
	[self.window addTitlebarAccessoryViewController:indexUpdateIndicator];
	_indexUpdateIndicator = indexUpdateIndicator;
}

- (void) removeIndexUpdateProgressController {
	if (!_indexUpdateIndicator) { return; }
	NSUInteger const index = [self.window.titlebarAccessoryViewControllers indexOfObject:_indexUpdateIndicator];
	if (index != NSNotFound) {
		[self.window removeTitlebarAccessoryViewControllerAtIndex:index];
	}
	_indexUpdateIndicator = nil;
}

@end

@implementation KBDocumentController (NSWindowRestoration)

static NSString *const KBDocumentControllerDocumentIDKey = @"documentID";

+ (void) restoreWindowWithIdentifier: (NSUserInterfaceItemIdentifier) identifier state: (NSCoder *) state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
	NSError *error = nil;
	KBDocumentMeta *const document = [self decodeDocumentForStateRestoration:state error:&error];
	if (document) {
		KBDocumentController *const controller = [KBDocumentController new];
		[controller window];
		controller.currentDocument = document;
		completionHandler (controller.window, nil);
	} else {
		completionHandler (nil, error);
	}
}

+ (KBDocumentMeta *) decodeDocumentForStateRestoration: (NSCoder *) state error: (NSError **) error {
	NSURL *const objectIDURL = [state decodeObjectOfClass:[NSURL class] forKey:KBDocumentControllerDocumentIDKey];
	if (!objectIDURL) { return nil; }
	NSManagedObjectID *const objectID = [[NSPersistentContainer sharedContainer].persistentStoreCoordinator managedObjectIDForURIRepresentation:objectIDURL];
	if (!objectID) { return nil; }
	return [[NSPersistentContainer sharedContainer].viewContext existingObjectWithID:objectID error:NULL];
}

- (void) window: (NSWindow *) window willEncodeRestorableState: (NSCoder *) state {
	[state encodeObject:self.currentDocument.objectID.URIRepresentation forKey:KBDocumentControllerDocumentIDKey];
}

@end

@implementation KBDocumentController (NSSearchFieldDelegate)

- (void) controlTextDidBeginEditing: (NSNotification *) sender {
	[self setSearchSheetHidden:!self.searchItem.searchField.stringValue.length];
	[self setSearchSheetQueryText:self.searchItem.searchField.stringValue];
}

- (void) controlTextDidChange: (NSNotification *) obj {
	[self setSearchSheetHidden:!self.searchItem.searchField.stringValue.length];
	[self setSearchSheetQueryText:self.searchItem.searchField.stringValue];
}

- (void) controlTextDidEndEditing: (NSNotification *) sender {
	[self setSearchSheetHidden:YES];
}

- (BOOL) control: (NSControl *) control textView: (NSTextView *) textView doCommandBySelector: (SEL) commandSelector {
	if ((control != self.searchItem.searchField) || ![textView isDescendantOf:self.searchItem.searchField]) {
		return NO;
	}
	if (commandSelector == @selector (moveDown:)) {
		return [self.searchSuggestionsPanelController selectNextSuggestion];
	} else if (commandSelector == @selector (moveUp:)) {
		return [self.searchSuggestionsPanelController selectPrevSuggestion];
	} else if (commandSelector == @selector (insertNewline:)) {
		return [self.searchSuggestionsPanelController confirmSuggestionSelection];
	} else if (commandSelector == @selector (scrollPageDown:)) {
		return [self.searchSuggestionsPanelController selectNextSuggestionsPage];
	} else if (commandSelector == @selector (scrollPageUp:)) {
		return [self.searchSuggestionsPanelController selectPrevSuggestionsPage];
	} else if (commandSelector == @selector (scrollToBeginningOfDocument:)) {
		return [self.searchSuggestionsPanelController selectFirstSuggestion];
	} else if (commandSelector == @selector (scrollToEndOfDocument:)) {
		return [self.searchSuggestionsPanelController selectLastSuggestion];
	}
	return NO;
}

@end

@implementation KBDocumentController (searchSuggestionsPanelManagement)

- (void) setSearchSheetHidden: (BOOL) searchSheetHidden {
	if (!searchSheetHidden != !self.searchSuggestionsPanelController) { return; }
	
	NSNotificationCenter *const center = [NSNotificationCenter defaultCenter];
	if (searchSheetHidden) {
		[center removeObserver:self name:NSWindowDidResizeNotification object:self.searchSuggestionsPanelController.window];
		[center addObserver:self selector:@selector (searchSuggestionsPanelWillClose) name:NSWindowWillCloseNotification object:self.searchSuggestionsPanelController.window];
		[self.window removeChildWindow:self.searchSuggestionsPanelController.window];
		[self.searchSuggestionsPanelController close];
		self.searchSuggestionsPanelController = nil;
	} else {
		KBSearchSuggestionsPanelController *const panelController = self.searchSuggestionsPanelController = [KBSearchSuggestionsPanelController new];
		[self.window addChildWindow:panelController.window ordered:NSWindowAbove];
		[self updateDocumentsSuggestionsPanelPosition];
		[center addObserver:self selector:@selector (updateDocumentsSuggestionsPanelPosition) name:NSWindowDidResizeNotification object:self.searchSuggestionsPanelController.window];
		[center addObserver:self selector:@selector (searchSuggestionsPanelWillClose) name:NSWindowWillCloseNotification object:self.searchSuggestionsPanelController.window];
	}
}

- (void) setSearchSheetQueryText: (NSString *) queryText {
	[self.searchSuggestionsPanelController setQueryText:queryText];
}

- (void) updateDocumentsSuggestionsPanelPosition {
	NSWindow *const panel = self.searchSuggestionsPanelController.window;
	if (!panel) { return; }
	CGRect const searchFieldFrame = [self.window convertRectToScreen:[self.searchItem.searchField convertRect:self.searchItem.searchField.bounds toView:nil]];
	CGRect const contentViewFrame = [self.window convertRectToScreen:[self.window.contentView convertRect:self.window.contentView.bounds toView:nil]];
	[panel setFrameTopLeftPoint:NSMakePoint (CGRectGetMidX (searchFieldFrame) - CGRectGetWidth (panel.frame) / 2, CGRectGetMinY (searchFieldFrame) - 2.0)];
	self.searchSuggestionsPanelController.maxSize = CGSizeMake (CGRectGetWidth (contentViewFrame) - 32.0, CGRectGetHeight (contentViewFrame) - 16.0);
}

- (void) searchSuggestionsPanelWillClose {
	[self.searchField endEditing:self.searchField.currentEditor];
}

@end

@interface KBDocumentControllerIndexUpdateIndicatorControllerView: NSView

@property (nonatomic, readonly, unsafe_unretained) NSProgressIndicator *indicator;

@end

@interface KBDocumentControllerIndexUpdateIndicatorController ()

@property (nonatomic, strong) KBDocumentControllerIndexUpdateIndicatorControllerView *view;

@end

@implementation KBDocumentControllerIndexUpdateIndicatorController

@dynamic view;

- (void) loadView {
	self.layoutAttribute = NSLayoutAttributeTrailing;
	
	KBDocumentControllerIndexUpdateIndicatorControllerView *const view = [KBDocumentControllerIndexUpdateIndicatorControllerView new];
	NSProgressIndicator *const indicator = view.indicator;
	self.view = view;
	
	indicator.doubleValue = [KBDocumentControllerIndexManager sharedManager].progress.doubleValue;
	__unsafe_unretained typeof (self) unsafeSelf = self;
	[self observeObject:[KBDocumentControllerIndexManager sharedManager] keyPath:@"progress" usingBlock:^{
		dispatch_async (dispatch_get_main_queue (), ^{
			NSProgressIndicator *const indicator = unsafeSelf.view.indicator;
			double const progress = indicator.doubleValue = [KBDocumentControllerIndexManager sharedManager].progress.doubleValue;
			indicator.toolTip = [NSString localizedStringWithFormat:NSLocalizedString (@"Index update: %.1f%%", nil), progress * 100];
		});
	}];
}

@end

@implementation KBDocumentControllerIndexUpdateIndicatorControllerView

- (instancetype) initWithFrame: (NSRect) frameRect {
	if (self = [super initWithFrame:(NSRect) { .origin = frameRect.origin, .size = NSMakeSize (38.0, 38.0) }]) {
		[self setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[self setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
		[self setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[self setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];

		NSProgressIndicator *const indicator = [NSProgressIndicator new];
		indicator.translatesAutoresizingMaskIntoConstraints = NO;
		indicator.style = NSProgressIndicatorStyleSpinning;
		indicator.indeterminate = NO;
		indicator.minValue = 0.0;
		indicator.maxValue = 1.0;
		indicator.controlSize = NSControlSizeSmall;
		[indicator setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[indicator setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
		[indicator setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[indicator setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
		[self addSubview:indicator];
		_indicator = indicator;
		
		[NSLayoutConstraint activateConstraints:[indicator constrainCenterToSuperviewCenter]];
	}
	return self;
}

- (void) setFrame: (NSRect) frame {
	[super setFrame:frame];
	[self invalidateIntrinsicContentSize];
}

- (void) setFrameSize: (NSSize) newSize {
	[super setFrameSize:newSize];
	[self invalidateIntrinsicContentSize];
}

- (NSSize) intrinsicContentSize {
	NSSize const indicatorSize = self.indicator.intrinsicContentSize, frameSize = self.frame.size;
	CGFloat const maxIndicatorSize = MAX (indicatorSize.width, indicatorSize.height);
	if (frameSize.width > maxIndicatorSize) {
		return NSMakeSize (frameSize.width, frameSize.width);
	} else if (frameSize.height > maxIndicatorSize) {
		return NSMakeSize (frameSize.height, frameSize.height);
	} else {
		return NSMakeSize (maxIndicatorSize, maxIndicatorSize);
	}
}

@end
