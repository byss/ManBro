//
//  NSString+searchPredicateValue.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSString+searchPredicateValue.h"

@implementation NSString (searchPredicateValue)

- (NSString *) stringByPreparingForCaseInsensitiveComparisonPredicates {
	static NSLocale *posixLocale;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		posixLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	});
	NSString *const result = [[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByFoldingWithOptions:NSCaseInsensitiveSearch locale:posixLocale];
	return result.length ? result : nil;
}

@end
