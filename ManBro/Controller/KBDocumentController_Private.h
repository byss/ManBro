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

@class KBDocument;
@class KBDocumentControllerSuggestionsPanel;
@protocol KBDocumentControllerSearchPanelDelegate <NSObject>

- (void) searchPanel: (KBDocumentControllerSuggestionsPanel *) panel didRequestDocument: (KBDocument *) document options: (KBDocumentRequestOptions) options;

@end

@interface KBDocumentControllerSuggestionsPanel: NSPanel

@property (weak) id <KBDocumentControllerSearchPanelDelegate> navigationDelegate;

- (void) setQueryText: (NSString *) queryText;

- (BOOL) selectNextSuggestion;
- (BOOL) selectPrevSuggestion;
- (BOOL) confirmSuggestionSelection;

@end


NS_ASSUME_NONNULL_END
