//
//  NSURL+documentController.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/8/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import "NSURL+documentController.h"

#import <objc/runtime.h>

@implementation NSURL (documentController)

@dynamic sourceIdentifier, targetIdentifier;

static NSString *const KBDocumentControllerSourceName = @"mb-source";
static NSString *const KBDocumentControllerTargetName = @"mb-target";

static NSUInteger KBDocumentControllerGetIdentifierFromURL (NSURL *self, SEL _cmd) {
	if (!objc_getAssociatedObject (self, KBDocumentControllerGetIdentifierFromURL)) {
		
		NSUInteger sourceIdentifier = 0, targetIdentifier = 0;
		NSURLComponents *const comps = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:YES];
		for (NSURLQueryItem *item in comps.queryItems) {
			NSUInteger *identifier;
			if ([item.name isEqualToString:KBDocumentControllerSourceName]) {
				identifier = &sourceIdentifier;
			} else if ([item.name isEqualToString:KBDocumentControllerTargetName]) {
				identifier = &targetIdentifier;
			} else {
				continue;
			}
			NSScanner *const scanner = [[NSScanner alloc] initWithString:item.value];
			unsigned long long value;
			if (![scanner scanHexLongLong:&value]) { continue; }
			*identifier = value;
		}
		
		objc_setAssociatedObject (self, KBDocumentControllerGetIdentifierFromURL, @YES, OBJC_ASSOCIATION_ASSIGN);
		objc_setAssociatedObject (self, @selector (sourceIdentifier), @(sourceIdentifier), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject (self, @selector (targetIdentifier), @(targetIdentifier), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return [objc_getAssociatedObject (self, _cmd) unsignedIntegerValue];
}

+ (BOOL) resolveInstanceMethod: (SEL) sel {
	if ((sel == @selector (sourceIdentifier)) || (sel == @selector (targetIdentifier))) {
		return class_addMethod (self, sel, (IMP) KBDocumentControllerGetIdentifierFromURL, (char const []) { _C_UINT, _C_ID, _C_SEL, '\0' });
	} else {
		return [super resolveInstanceMethod:sel];
	}
}

- (instancetype) initWithTargetURL: (NSURL *) url sourceURL: (NSURL *) sourceURL {
	return [self initWithTargetURL:url sourceIdentifier:sourceURL.sourceIdentifier targetIdentifier:sourceURL.targetIdentifier];
}

- (instancetype) initWithTargetURL: (NSURL *) url sourceIdentifier: (NSUInteger) sourceIdentifier {
	return [self initWithTargetURL:url sourceIdentifier:sourceIdentifier targetIdentifier:0];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype) initWithTargetURL: (NSURL *) url sourceIdentifier: (NSUInteger) sourceIdentifier targetIdentifier: (NSUInteger) targetIdentifier {
	if (!(sourceIdentifier || targetIdentifier)) { return url; }
	NSURLComponents *const comps = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:YES];
	NSMutableArray <NSURLQueryItem *> *const queryItems = [[NSMutableArray alloc] initWithCapacity:2];
	sourceIdentifier ? [queryItems addObject:[[NSURLQueryItem alloc] initWithName:KBDocumentControllerSourceName value:[[NSString alloc] initWithFormat:@"%llx", (unsigned long long) sourceIdentifier]]] : (void) 0;
	targetIdentifier ? [queryItems addObject:[[NSURLQueryItem alloc] initWithName:KBDocumentControllerTargetName value:[[NSString alloc] initWithFormat:@"%llx", (unsigned long long) targetIdentifier]]] : (void) 0;
	comps.queryItems = comps.queryItems.count ? [comps.queryItems arrayByAddingObjectsFromArray:queryItems] : queryItems;
	return comps.URL;
}
#pragma clang diagnostic pop

@end
