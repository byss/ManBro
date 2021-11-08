//
//  KBPrefix.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBPrefix.h"

@implementation KBPrefix

+ (instancetype) fetchOrCreatePrefixWithURL: (NSURL *) url context: (NSManagedObjectContext *) context {
	url = url.absoluteURL;
	NSFetchRequest *req = [self fetchRequest];
	req.predicate = [NSPredicate predicateWithFormat:@"url == %@", url];
	req.fetchLimit = 1;
	req.resultType = NSManagedObjectResultType;
	KBPrefix *result = [context executeFetchRequest:req error:NULL].firstObject;
	if (!result) {
		result = [[KBPrefix alloc] initWithContext:context];
		result.url = url;
	}
	return result;
}

@end
