//
//  NSManagedObject+convenience.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSManagedObject+convenience.h"

#import "NSPersistentContainer+sharedContainer.h"

@implementation NSManagedObject (convenience)

+ (NSFetchRequest *) fetchRequestFromTemplateWithName: (NSString *) templateName substitutionVariables: (NSDictionary <NSString *, id> *) variables {
	return [[NSPersistentContainer sharedContainer].managedObjectModel fetchRequestFromTemplateWithName:templateName substitutionVariables:variables];
}

- (id) valueForKey: (NSString *) key notifyObservers: (BOOL) notifyObservers {
	return [self valueForKey:key notifyObservers:notifyObservers transform:NULL];
}

- (id) valueForKey: (NSString *) key notifyObservers: (BOOL) notifyObservers transform: (id (^NS_NOESCAPE __nullable) (id)) transform {
	if (notifyObservers) { [self willAccessValueForKey:key]; }
	id const primitiveValue = [self primitiveValueForKey:key];
	id const result = transform ? transform (primitiveValue) : primitiveValue;
	if (notifyObservers) { [self didAccessValueForKey:key]; }
	return result;
}

- (void) setValue: (id) value forKey: (NSString *) key notifyObservers: (BOOL) notifyObservers {
	[self setValue:value forKey:key notifyObservers:notifyObservers additionalActions:NULL];
}

- (void) setValue: (id) value forKey: (NSString *) key notifyObservers: (BOOL) notifyObservers additionalActions: (void (^NS_NOESCAPE) (void)) additionalActions {
	if ([[self primitiveValueForKey:key] isEqual:value]) { return; }
	if (notifyObservers) { [self willChangeValueForKey:key]; }
	[self setPrimitiveValue:value forKey:key];
	if (additionalActions) { additionalActions (); }
	if (notifyObservers) { [self didChangeValueForKey:key]; }
}

@end

NSDictionary <NSString *, id> *_KBVariables (NSString *keysString, ...) {
	NSArray <NSString *> *const keysStringComponents = [keysString componentsSeparatedByString:@","];
	NSMutableDictionary <NSString *, id> *const result = [[NSMutableDictionary alloc] initWithCapacity:keysStringComponents.count];
	NSCharacterSet *const whitespaceAndNewlineCharset = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	va_list args;
	va_start (args, keysString);
	for (NSString *key in keysStringComponents) {
		result [[key stringByTrimmingCharactersInSet:whitespaceAndNewlineCharset]] = va_arg (args, id);
	}
	va_end (args);
	return [[NSDictionary alloc] initWithDictionary:result];
}
