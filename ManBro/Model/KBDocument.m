//
//  KBDocument.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocument.h"
#import "KBPrefix.h"

@interface KBManPageURLComponents: NSObject

@property (nonatomic, readonly) NSURL *prefix;
@property (nonatomic, readonly) NSString *section;
@property (nonatomic, readonly) NSString *documentName;

@property (nonatomic, readonly) NSURL *documentURL;

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (nullable instancetype) initWithURL: (NSURL *) documentURL;
- (instancetype) initWithDocument: (KBDocument *) document;

@end

@implementation KBDocument

+ (instancetype) fetchOrCreateDocumentWithURL: (NSURL *) url context: (NSManagedObjectContext *) context {
	KBManPageURLComponents *comps = [[KBManPageURLComponents alloc] initWithURL:url];
	if (!comps) {
		return nil;
	}
	KBPrefix *const prefix = [KBPrefix fetchOrCreatePrefixWithURL:comps.prefix context:context];
	NSFetchRequest *req = [self fetchRequest];
	req.predicate = [NSPredicate predicateWithFormat:@"prefix == %@ AND section = %@ AND name = %@", prefix, comps.section, comps.documentName];
	req.fetchLimit = 1;
	req.resultType = NSManagedObjectResultType;
	KBDocument *result = [context executeFetchRequest:req error:NULL].firstObject;
	if (!result) {
		result = [[KBDocument alloc] initWithContext:context];
		result.section = comps.section;
		result.name = comps.documentName;
		result.prefix = prefix;
	}
	return result;
}

- (NSURL *) url {
	return [[KBManPageURLComponents alloc] initWithDocument:self].documentURL;
}

@end

@interface KBManPageURLComponents ()

- (instancetype) initWithPrefix: (NSURL *) prefix section: (NSString *) section documentName: (NSString *) documentName NS_DESIGNATED_INITIALIZER;

@end

@implementation KBManPageURLComponents

@synthesize documentURL = _documentURL;

- (instancetype) init { return [self initWithURL:nil]; }

- (instancetype) initWithURL: (NSURL *) documentURL {
	if (!documentURL) {
		return nil;
	}
	NSString *const section = documentURL.pathExtension;
	if (!section.length) {
		return nil;
	}
	documentURL = [documentURL URLByDeletingPathExtension];
	NSString *const documentName = documentURL.lastPathComponent;
	if (!documentName.length || [documentName isEqualToString:@"/"]) {
		return nil;
	}
	documentURL = [documentURL.absoluteURL URLByDeletingLastPathComponent];
	if (![documentURL.lastPathComponent isEqualToString:[[NSString alloc] initWithFormat:@"man%@", section]]) {
		return nil;
	}
	documentURL = [documentURL URLByDeletingLastPathComponent];
	if (![documentURL.lastPathComponent isEqualToString:@"man"]) {
		return nil;
	}
	NSURL *const prefix = [documentURL URLByDeletingLastPathComponent];
	return [self initWithPrefix:prefix section:section documentName:documentName];
}

- (instancetype) initWithDocument: (KBDocument *) document {
	return [self initWithPrefix:document.prefix.url section:document.section documentName:document.name];
}

- (instancetype) initWithPrefix: (NSURL *) prefix section: (NSString *) section documentName: (NSString *) documentName {
	if (self = [super init]) {
		_section = [section copy];
		_documentName = [documentName copy];
		_prefix = [prefix copy];
	}
	return self;
}

- (NSURL *) documentURL {
	if (!_documentURL) {
		_documentURL = self.prefix;
		_documentURL = [_documentURL URLByAppendingPathComponent:@"man" isDirectory:YES];
		_documentURL = [_documentURL URLByAppendingPathComponent:[[NSString alloc] initWithFormat:@"man%@", self.section] isDirectory:YES];
		_documentURL = [_documentURL URLByAppendingPathComponent:self.documentName isDirectory:NO];
		_documentURL = [_documentURL URLByAppendingPathExtension:self.section];
	}
	return _documentURL;
}

@end
