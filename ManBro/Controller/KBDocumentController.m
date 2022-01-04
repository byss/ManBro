//
//  KBDocumentController.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import <WebKit/WebKit.h>

#import "KBTask.h"
#import "KBSection.h"
#import "KBPrefix.h"
#import "CoreData+logging.h"
#import "NSObject+abstract.h"
#import "KBDocumentLoading.h"
#import "KBDocumentTOCItem.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentController (NSWindowDelegate) <NSWindowDelegate>
@end
@interface KBDocumentController (NSSearchFieldDelegate) <NSSearchFieldDelegate>
@end
@interface KBDocumentController (KBDocumentControllerSearchPanelDelegate) <KBDocumentControllerSearchPanelDelegate>
@end
@interface KBDocumentController (NSTextFinderBarContainer) <NSTextFinderBarContainer>
@end
@interface KBDocumentController (NSWindowRestoration) <NSWindowRestoration>
@end
@interface KBDocumentController (NSUserInterfaceValidations) <NSUserInterfaceValidations>
@end
@interface KBDocumentController (WKNavigationDelegate) <WKNavigationDelegate>
@end

@interface KBDocumentController (suggestionsPanelManagement)

- (void) setSearchSheetHidden: (BOOL) searchSheetHidden;
- (void) setSearchSheetQueryText: (NSString *) queryText;
- (void) updateDocumentsSuggestionsPanelPosition;

@end

@interface KBDocumentController (TOCManagement) <KBDocumentControllerTOCPopoverDelegate>

- (IBAction) showTOC: (id) sender;

@end

@interface KBDocumentController ()

@property (nonatomic, unsafe_unretained) IBOutlet NSSearchToolbarItem *searchItem;
@property (nonatomic, unsafe_unretained) KBDocumentControllerSuggestionsPanel *documentSuggestionsPanel;
@property (nonatomic, unsafe_unretained) KBDocumentControllerTOCPopover *tocPopover;
@property (nonatomic, readonly) NSView *contentView;
@property (nonatomic, unsafe_unretained, readonly) WKWebView *webView;
@property (nonatomic, readonly) NSTextFinder *textFinder;
@property (nonatomic, strong) NSView *findBarView;
@property (nonatomic, strong) KBDocumentMeta *currentDocument;

- (instancetype) init NS_DESIGNATED_INITIALIZER;

@end

static NSString *const KBDocumentControllerClassName = @"KBDocumentController";
static NSMutableSet <KBDocumentController *> *KBDocumentControllerInstances = nil;

@implementation KBDocumentController

+ (BOOL) accessInstanceVariablesDirectly {
	return YES;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype) init {
	return [super initWithWindowNibName:KBDocumentControllerClassName];
}

- (instancetype) initWithWindowNibName: (NSNibName) windowNibName owner: (id) owner {
	return [super initWithWindowNibName:KBDocumentControllerClassName owner:owner];
}
#pragma clang diagnostic pop

- (instancetype) initWithWindow: (NSWindow *) window {
	return [super initWithWindow:window];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
	return [super initWithCoder:coder];
}

- (instancetype) initWithWindowNibName: (NSNibName) windowNibName KB_ABSTRACT;
- (instancetype) initWithWindowNibPath: (NSString *) windowNibPath owner: (id) owner KB_ABSTRACT;

- (NSView *) contentView { return self.window.contentView; }

- (void) setCurrentDocument: (KBDocumentMeta *) document {
	_currentDocument = document;
	
	if (document) {
		self.window.title = [[NSString alloc] initWithFormat:@"%@ (%@)", document.title, document.section.name];
		self.window.representedURL = document.URL;
		self.window.tab.toolTip = document.URL.fileSystemRepresentation ? @(document.URL.fileSystemRepresentation) : nil;
		[self.window.toolbar validateVisibleItems];
		[self populateCurrentDocumentTOCIfNeeded];
	} else {
		self.window.title = NSLocalizedString (@"Loading…", nil);
		self.window.representedURL = nil;
		self.window.tab.toolTip = nil;
	}
}

- (void) populateCurrentDocumentTOCIfNeeded {
	if (self.currentDocument.toc) { return; }
	NSManagedObjectID *const currentDocumentID = self.currentDocument.objectID;
	[self.webView callAsyncJavaScript:@"return getHeadings (document);" arguments:nil inFrame:nil inContentWorld:WKContentWorld.pageWorld completionHandler:^(id result, NSError *error) {
		if (error) { return; }
		[[NSPersistentContainer sharedContainer] performBackgroundTask:^(NSManagedObjectContext *context) {
			KBDocumentMeta *const document = [context objectWithID:currentDocumentID];
			[document populateTOCUsingData:result];
			[context save];
			
			dispatch_async (dispatch_get_main_queue (), ^{
				if ([self.currentDocument.objectID isEqual:currentDocumentID]) {
					[self.window.toolbar validateVisibleItems];
				}
			});
		}];
	}];
}

@end

@implementation KBDocumentController (suggestionsPanelManagement)

- (void) setSearchSheetHidden: (BOOL) searchSheetHidden {
	if (!searchSheetHidden != !self.documentSuggestionsPanel) { return; }

	if (searchSheetHidden) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:self.documentSuggestionsPanel];
		[self.window removeChildWindow:self.documentSuggestionsPanel];
		[self.documentSuggestionsPanel close];
		self.documentSuggestionsPanel = nil;
	} else {
		KBDocumentControllerSuggestionsPanel *const panel = [KBDocumentControllerSuggestionsPanel new];
		panel.navigationDelegate = self;
		self.documentSuggestionsPanel = panel;
		[self.window addChildWindow:panel ordered:NSWindowAbove];
		[self updateDocumentsSuggestionsPanelPosition];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector (updateDocumentsSuggestionsPanelPosition) name:NSWindowDidResizeNotification object:self.documentSuggestionsPanel];
	}
}

- (void) setSearchSheetQueryText: (NSString *) queryText {
	[self.documentSuggestionsPanel setQueryText:queryText];
}

- (void) updateDocumentsSuggestionsPanelPosition {
	NSWindow *const panel = self.documentSuggestionsPanel;
	if (!panel) { return; }
	CGRect const searchFieldFrame = [self.window convertRectToScreen:[self.searchItem.searchField convertRect:self.searchItem.searchField.bounds toView:nil]];
	CGRect const contentViewFrame = [self.window convertRectToScreen:[self.window.contentView convertRect:self.window.contentView.bounds toView:nil]];
	[panel setFrameTopLeftPoint:NSMakePoint (CGRectGetMidX (searchFieldFrame) - CGRectGetWidth (panel.frame) / 2, CGRectGetMinY (searchFieldFrame) - 2.0)];
	panel.maxSize = CGSizeMake (CGRectGetWidth (contentViewFrame) - 32.0, CGRectGetHeight (contentViewFrame) - 16.0);
}

@end

@implementation KBDocumentController (TOCManagement)

- (IBAction) showTOC: (NSButton *) sender {
	if (self.tocPopover) {
		return [self.tocPopover close];
	}
	
	KBDocumentControllerTOCPopover *const popover = [[KBDocumentControllerTOCPopover alloc] initWithTOC:self.currentDocument.toc];
	popover.delegate = self;
	[popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMinYEdge];
	self.tocPopover = popover;
}

- (void) popoverDidClose: (NSNotification *) notification {
	self.tocPopover = nil;
}

- (void) tocPopover: (KBDocumentControllerTOCPopover *) popover didSelectTOCItem: (KBDocumentTOCItem *) item {
	NSString *const script = [[NSString alloc] initWithFormat:@"document.location.hash = \"%@\"", item.anchor];
	[self.webView evaluateJavaScript:script completionHandler:NULL];
}

@end

@implementation KBDocumentController (documentLoading)

- (void) loadDocument: (KBDocumentMeta *) document {
	[self loadDocumentAtURL:document.loaderURI];
}

- (void) loadDocumentAtURL: (NSURL *) documentURL {
	[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:documentURL]];
}

@end

@implementation KBDocumentController (NSWindowDelegate)

- (void) windowDidLoad {
	[super windowDidLoad];
	
	self.window.restorable = YES;
	self.window.restorationClass = self.class;

	WKWebViewConfiguration *const config = [WKWebViewConfiguration new];
	KBDocumentBodyLoader *const documentBodyLoader = [KBDocumentBodyLoader new];
	[config setURLSchemeHandler:documentBodyLoader forURLScheme:KBDocumentBodyLoader.scheme];
	[config setURLSchemeHandler:[KBDocumentBundledResourceLoader new] forURLScheme:KBDocumentBundledResourceLoader.scheme];
	
	WKWebView *const webView = [[WKWebView alloc] initWithFrame:self.window.contentLayoutRect configuration:config];
	webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	webView.navigationDelegate = self;
	_webView = webView;
	
	NSTextFinder *textFinder = [NSTextFinder new];
	textFinder.client = webView;
	textFinder.findBarContainer = self;
	_textFinder = textFinder;
	
	NSView *const contentView = [[NSView alloc] initWithFrame:self.window.contentLayoutRect];
	contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[contentView addSubview:webView];
	self.window.contentView = contentView;
	
	if (KBDocumentControllerInstances) {
		[KBDocumentControllerInstances addObject:self];
	} else {
		KBDocumentControllerInstances = [[NSMutableSet alloc] initWithObjects:self, nil];
	}
}

- (void) windowWillClose: (NSNotification *) notification {
	[KBDocumentControllerInstances removeObject:self];
}

- (void) windowDidMove: (NSNotification *) notification {
	[self updateDocumentsSuggestionsPanelPosition];
	[self.tocPopover close];
}

- (void) windowDidResize: (NSNotification *) notification {
	[self updateDocumentsSuggestionsPanelPosition];
	self.findBarVisible ? [self findBarViewDidChangeHeight] : (void) 0;
	[self.tocPopover close];
}

- (void) windowDidBecomeKey: (NSNotification *) notification {
	self.findBarVisible ? [self findBarViewDidChangeHeight] : (void) 0;
}

- (void) windowDidBecomeMain: (NSNotification *) notification {
	self.findBarVisible ? [self findBarViewDidChangeHeight] : (void) 0;
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
		return [self.documentSuggestionsPanel selectNextSuggestion];
	} else if (commandSelector == @selector (moveUp:)) {
		return [self.documentSuggestionsPanel selectPrevSuggestion];
	} else if (commandSelector == @selector (insertNewline:)) {
		return [self.documentSuggestionsPanel confirmSuggestionSelection];
	} else if (commandSelector == @selector (scrollPageDown:)) {
		return [self.documentSuggestionsPanel selectNextSuggestionsPage];
	} else if (commandSelector == @selector (scrollPageUp:)) {
		return [self.documentSuggestionsPanel selectPrevSuggestionsPage];
	} else if (commandSelector == @selector (scrollToBeginningOfDocument:)) {
		return [self.documentSuggestionsPanel selectFirstSuggestion];
	} else if (commandSelector == @selector (scrollToEndOfDocument:)) {
		return [self.documentSuggestionsPanel selectLastSuggestion];
	}
	return NO;
}

@end

@implementation KBDocumentController (KBDocumentControllerSuggestionsPanelDelegate)

- (void) searchPanel: (KBDocumentControllerSuggestionsPanel *) panel didRequestDocument: (KBDocumentMeta *) document options: (KBDocumentRequestOptions) options {
	[self setSearchSheetHidden:YES];
	[self.searchItem.searchField endEditing:self.searchItem.searchField.currentEditor];
	
	KBDocumentController *controller;
	if (options & KBCreateDocumentWindow) {
		controller = [KBDocumentController new];
		controller.searchItem.searchField.stringValue = self.searchItem.searchField.stringValue;
	} else if (options & KBReplaceCurrentContext) {
		controller = self;
	} else {
		return;
	}
	[controller loadDocument:document];
	if (options & KBReplaceCurrentContext) {
		[controller.window makeKeyAndOrderFront:panel];
	}
}

@end

@implementation KBDocumentController (NSTextFinderBarContainer)

- (BOOL) isFindBarVisible {
	return self.contentView.subviews.count > 1;
}

- (void) setFindBarVisible: (BOOL) findBarVisible {
	if (findBarVisible == self.findBarVisible) { return; }
	
	if (findBarVisible) {
		if (self.findBarView) {
			[self.contentView addSubview:self.findBarView];
			[self findBarViewDidChangeHeight];
		}
	} else {
		[self.findBarView removeFromSuperview];
		self.webView.frame = self.contentView.bounds;
	}
}

- (void) findBarViewDidChangeHeight {
	CGFloat const contentWidth = CGRectGetWidth (self.contentView.bounds), contentHeight = CGRectGetHeight (self.contentView.bounds);
	CGFloat const findBarViewHeight = CGRectGetHeight (self.findBarView.bounds);
	self.findBarView.frame = NSMakeRect (0.0, 0.0, contentWidth, findBarViewHeight);
	self.webView.frame = NSMakeRect (0.0, findBarViewHeight, contentWidth, contentHeight - findBarViewHeight);
}

- (IBAction) performTextFinderAction: (id <NSValidatedUserInterfaceItem>) sender {
	[self.textFinder performAction:sender.tag];
}

@end

@implementation KBDocumentController (NSWindowRestoration)

static NSString *const KBDocumentControllerWebViewURL = @"webViewURL";

+ (void) restoreWindowWithIdentifier: (NSUserInterfaceItemIdentifier) identifier state: (NSCoder *) state completionHandler: (void (^)(NSWindow *, NSError *)) completionHandler {
	KBDocumentController *const controller = [KBDocumentController new];
	NSURL *const webViewURL = [state decodeObjectOfClass:[NSURL class] forKey:KBDocumentControllerWebViewURL];
	[controller window];
	if (webViewURL) { [controller loadDocumentAtURL:webViewURL]; }
	completionHandler (controller.window, nil);
}

- (void) window: (NSWindow *) window willEncodeRestorableState: (NSCoder *) state {
	NSURL *const webViewURL = self.webView.URL;
	[state encodeObject:webViewURL forKey:KBDocumentControllerWebViewURL];
}

@end

@implementation KBDocumentController (NSUserInterfaceValidations)

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) item {
	if (item.action == @selector (goBack:)) {
		return self.webView.canGoBack;
	} else if (item.action == @selector (goForward:)) {
		return self.webView.canGoForward;
	} else if (item.action == @selector (performTextFinderAction:)) {
		return self.webView.URL && [self.textFinder validateAction:item.tag];
	} else if (item.action == @selector (showTOC:)) {
		return self.currentDocument.toc.hasChildren;
	} else {
		return NO;
	}
}

@end

@implementation KBDocumentController (WKNavigationDelegate)

- (IBAction) goBack: (id) sender {
	[self.webView goBack:sender];
}

- (IBAction) goForward: (id) sender {
	[self.webView goForward:sender];
}

- (void) webView: (WKWebView *) webView decidePolicyForNavigationAction: (WKNavigationAction *) navigationAction preferences: (WKWebpagePreferences *) preferences decisionHandler: (void (^)(WKNavigationActionPolicy, WKWebpagePreferences *)) decisionHandler {
	NSURL *const targetURL = navigationAction.request.URL;
	NSString *const targetScheme = targetURL.scheme;
	if ([targetScheme isEqualToString:KBManScheme]) {
		decisionHandler (WKNavigationActionPolicyCancel, nil);
		BOOL const openInNewWindow = !!(navigationAction.modifierFlags & NSEventModifierFlagCommand);
		[[KBManSchemeURLResolver sharedResolver] resolveManURL:targetURL relativeToDocumentURL:webView.URL completion:^(NSURL *resolvedURL, NSError *error) {
			dispatch_async (dispatch_get_main_queue (), ^{
				if (resolvedURL) {
					if (openInNewWindow) {
						KBDocumentController *const controller = [KBDocumentController new];
						[controller.window makeKeyAndOrderFront:self];
						[controller loadDocumentAtURL:resolvedURL];
					} else {
						[webView loadRequest:[[NSURLRequest alloc] initWithURL:resolvedURL]];
					}
				} else {
					[self presentError:error];
				}
			});
		}];
	} else if ([WKWebView handlesURLScheme:targetScheme] || [webView.configuration urlSchemeHandlerForURLScheme:targetScheme]) {
		decisionHandler (WKNavigationActionPolicyAllow, preferences);
	} else {
		decisionHandler (WKNavigationActionPolicyCancel, nil);
	}
}

- (void) webView: (WKWebView *) webView didStartProvisionalNavigation: (WKNavigation *) navigation {
	self.currentDocument = nil;
}

- (void) webView: (WKWebView *) webView didFinishNavigation: (WKNavigation *) navigation {
	dispatch_async (dispatch_get_main_queue (), ^{
		self.currentDocument = [[KBDocumentMeta alloc] initWithLoaderURI:webView.URL context:[NSPersistentContainer sharedContainer].viewContext];
	});
}

- (void) webView: (WKWebView *) webView didFailProvisionalNavigation: (WKNavigation *) navigation withError: (NSError *) error {
	[self webView:webView didFailNavigation:navigation withError:error];
}

- (void) webView: (WKWebView *) webView didFailNavigation: (WKNavigation *) navigation withError: (NSError *) error {
	if ([error.domain isEqualToString:WKErrorDomain]) { return; }
	dispatch_async (dispatch_get_main_queue (), ^{ [self presentError:error]; });
}

@end

@interface KBToolbarItem: NSToolbarItem
@end

@implementation KBToolbarItem

- (void) validate {
	self.enabled =  [self _validateNow];
}

- (BOOL) _validateNow {
	id const target = [NSApp targetForAction:self.action to:self.target from:self];
	if (![target respondsToSelector:self.action]) { return NO; }
	if ([target respondsToSelector:@selector (validateToolbarItem:)]) {
		if (![target validateToolbarItem:self]) { return NO; }
	} else if ([target respondsToSelector:@selector (validateUserInterfaceItem:)]) {
		if (![target validateUserInterfaceItem:self]) { return NO; }
	}
	return YES;
}

@end

#import <objc/runtime.h>

@interface WKWebView (notEditable)
@end

@implementation WKWebView (notEditable)

+ (void) load {
	class_addMethod (self, @selector (isEditable), imp_implementationWithBlock (^(id self) { return NO; }), (char const []) { _C_BOOL, _C_ID, _C_SEL, '\0' });
}

@end
