//
//  KBDocumentController_Private.h
//  ManBro
//
//  Created by Kirill Bystrov on 11/8/21.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, KBDocumentRequestOptions) {
	KBDocumentBecomesCurrent = 1 << 0,
	KBCreateDocumentWindow = 1 << 1,
	
	KBIgnoreDocument = 0,
	KBReplaceCurrentContext = KBDocumentBecomesCurrent,
	KBOpenBackgroundWindow = KBCreateDocumentWindow,
	KBOpenForegroundWindow = KBDocumentBecomesCurrent | KBCreateDocumentWindow,
};

@class KBDocumentMeta;
@class KBDocumentControllerSuggestionsPanel;
@protocol KBDocumentControllerSearchPanelDelegate <NSObject>

@required
- (void) searchPanel: (KBDocumentControllerSuggestionsPanel *) panel didRequestDocument: (KBDocumentMeta *) document options: (KBDocumentRequestOptions) options;

@end

@interface KBDocumentControllerSuggestionsPanel: NSPanel

@property (weak) id <KBDocumentControllerSearchPanelDelegate> navigationDelegate;

- (void) setQueryText: (NSString *) queryText;

- (BOOL) selectNextSuggestion;
- (BOOL) selectPrevSuggestion;
- (BOOL) selectNextSuggestionsPage;
- (BOOL) selectPrevSuggestionsPage;
- (BOOL) selectFirstSuggestion;
- (BOOL) selectLastSuggestion;
- (BOOL) confirmSuggestionSelection;

@end

@class KBDocumentTOCItem;
@class KBDocumentControllerTOCPopover;
@protocol KBDocumentControllerTOCPopoverDelegate <NSPopoverDelegate>

@required
- (void) tocPopover: (KBDocumentControllerTOCPopover *) popover didSelectTOCItem: (KBDocumentTOCItem *) item;

@end

@interface KBDocumentControllerTOCPopover: NSPopover

@property (nullable, weak) id <KBDocumentControllerTOCPopoverDelegate> delegate;

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithCoder: (NSCoder *) coder NS_UNAVAILABLE;

- (instancetype) initWithTOC: (KBDocumentTOCItem *) toc NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
