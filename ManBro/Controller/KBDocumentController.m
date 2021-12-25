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
#import "NSObject+abstract.h"
#import "KBDocumentLoading.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentController (NSWindowDelegate) <NSWindowDelegate>
@end
@interface KBDocumentController (NSSearchFieldDelegate) <NSSearchFieldDelegate>
@end
@interface KBDocumentController (KBDocumentControllerSearchPanelDelegate) <KBDocumentControllerSearchPanelDelegate>
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

@interface KBDocumentController ()

@property (nonatomic, unsafe_unretained) IBOutlet NSSearchToolbarItem *searchItem;
@property (nonatomic, unsafe_unretained) KBDocumentControllerSuggestionsPanel *documentSuggestionsPanel;
@property (nonatomic, readonly) IBOutlet WKWebView *webView;

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

- (WKWebView *) webView { return self.window.contentView; }

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

	WKWebViewConfiguration *const config = [WKWebViewConfiguration new];
	KBDocumentBodyLoader *const documentBodyLoader = [KBDocumentBodyLoader new];
	[config setURLSchemeHandler:documentBodyLoader forURLScheme:KBDocumentBodyLoader.scheme];
	[config setURLSchemeHandler:[KBDocumentBundledResourceLoader new] forURLScheme:KBDocumentBundledResourceLoader.scheme];
	
	WKWebView *const webView = [[WKWebView alloc] initWithFrame:self.window.contentLayoutRect configuration:config];
	webView.navigationDelegate = self;
	self.window.contentView = webView;
	
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
}

- (void) windowDidResize: (NSNotification *) notification {
	[self updateDocumentsSuggestionsPanelPosition];
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

@implementation KBDocumentController (NSUserInterfaceValidations)

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) item {
	if (item.action == @selector (goBack:)) {
		return self.webView.canGoBack;
	} else if (item.action == @selector (goForward:)) {
		return self.webView.canGoForward;
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

- (void)webView: (WKWebView *) webView decidePolicyForNavigationAction: (WKNavigationAction *) navigationAction preferences: (WKWebpagePreferences *) preferences decisionHandler: (void (^)(WKNavigationActionPolicy, WKWebpagePreferences *)) decisionHandler {
	NSURL *const targetURL = navigationAction.request.URL;
	NSString *const targetScheme = targetURL.scheme;
	if ([targetScheme isEqualToString:KBManScheme]) {
		decisionHandler (WKNavigationActionPolicyCancel, nil);
		[[KBManSchemeURLResolver sharedResolver] resolveManURL:targetURL relativeToDocumentURL:webView.URL completion:^(NSURL *resolvedURL, NSError *error) {
			dispatch_async (dispatch_get_main_queue (), ^{
				if (resolvedURL) {
					[webView loadRequest:[[NSURLRequest alloc] initWithURL:resolvedURL]];
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
	self.window.title = NSLocalizedString (@"Loading…", nil);
	self.window.representedURL = nil;
	self.window.tab.toolTip = nil;
}

- (void) webView: (WKWebView *) webView didFinishNavigation: (WKNavigation *) navigation {
	dispatch_async (dispatch_get_main_queue (), ^{
		KBDocumentMeta *const document = [[KBDocumentMeta alloc] initWithLoaderURI:webView.URL context:[NSPersistentContainer sharedContainer].viewContext];
		self.window.title = [[NSString alloc] initWithFormat:@"%@ (%@)", document.title, document.section.name];
		self.window.representedURL = document.URL;
		self.window.tab.toolTip = document.URL.fileSystemRepresentation ? @(document.URL.fileSystemRepresentation) : nil;
		[self.window.toolbar validateVisibleItems];
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
