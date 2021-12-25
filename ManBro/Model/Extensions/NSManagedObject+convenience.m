//
//  NSManagedObject+convenience.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSManagedObject+convenience.h"

#import <os/log.h>

#import "CoreData+logging.h"
#import "NSComparisonPredicate+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface NSArray (KBManagedObjectPropertyNames)

- (NSArray <NSString *> *) arrayByValidatingObjectsAsPropertyNamesForEntity: (NSEntityDescription *) entity;

@end

@implementation NSManagedObject (convenience)

+ (NSArray <NSString *> *) validatedArrayOfPropertyNames: (NSArray <NSString *> *) sourceArray {
	return [sourceArray arrayByValidatingObjectsAsPropertyNamesForEntity:self.entity];
}

+ (NSFetchRequest <__kindof NSManagedObject *> *) fetchRequestForObjectsWithValues: (NSArray *) values forPropertiesNamed: (NSArray <NSString *> *) propertyNames {
	NSParameterAssert (values.count == propertyNames.count);
	NSArray <NSString *> *const validatedNames = [self validatedArrayOfPropertyNames:propertyNames];
	if (!validatedNames) {
		os_log_t const log = os_log_create ("CoreData", "NSManagedObject");
		os_log_fault (log, "%{public}@ (%{public}@): invalid properties list: '%{public}@'", self, self.entity.name, propertyNames);
		abort ();
	}
	
	NSUInteger const count = propertyNames.count;
	NSFetchRequest *const result = [self fetchRequest];
	if (count) {
		NSMutableArray <NSPredicate *> *subpredicates = [[NSMutableArray alloc] initWithCapacity:count];
		for (NSUInteger i = 0; i < count; i++) {
			[subpredicates addObject:[[NSComparisonPredicate alloc] initWithType:NSEqualToPredicateOperatorType forKeyPath:propertyNames [i] value:values [i]]];
		}
		result.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:subpredicates];
	}
	return result;
}

+ (NSArray <__kindof NSManagedObject *> *) fetchObjectsWithValues: (NSArray *) values forPropertiesNamed: (NSArray <NSString *> *) propertyNames inContext: (NSManagedObjectContext *) context {
	return [context executeFetchRequest:[self fetchRequestForObjectsWithValues:values forPropertiesNamed:propertyNames]];
}

+ (instancetype __nullable) fetchUniqueObjectWithValues: (NSArray *) values forPropertiesNamed: (NSArray <NSString *> *) propertyNames inContext: (NSManagedObjectContext *) context {
	NSFetchRequest *const req = [self fetchRequestForObjectsWithValues:values forPropertiesNamed:propertyNames];
#if DEBUG
	if ([context countForFetchRequest:req] > 1) {
		os_log_t const log = os_log_create ("CoreData", "NSManagedObject");
		os_log_error (log, "%{public}@ (%{public}@): multiple objects match predicate '%{public}@', violating soft uniqueness constraint; beware potential trouble", self, self.entity.name, req.predicate);
	}
#else
	req.fetchLimit = 1;
#endif
	return [self fetchObjectsWithValues:values forPropertiesNamed:propertyNames inContext:context].firstObject;
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

@interface KBManagedObjectPropertyNames: NSArray <NSString *>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithCoder: (NSCoder *) coder NS_UNAVAILABLE;
- (instancetype) initWithObjects: (id const []) objects count: (NSUInteger) cnt NS_UNAVAILABLE;

- (instancetype) initWithEntity: (NSEntityDescription *) entity propertyNames: (NSArray <NSString *> *) propertyNames NS_DESIGNATED_INITIALIZER;

@end

@implementation NSArray (KBManagedObjectPropertyNames)

- (NSArray <NSString *> *) arrayByValidatingObjectsAsPropertyNamesForEntity: (NSEntityDescription *) entity {
	return [[KBManagedObjectPropertyNames alloc] initWithEntity:entity propertyNames:self];
}

@end

@implementation KBManagedObjectPropertyNames {
	NSEntityDescription *_entity;
	NSArray <NSString *> *_backing;
}

- (instancetype) initWithEntity: (NSEntityDescription *) entity propertyNames: (NSArray <NSString *> *) propertyNames {
	for (NSString *propertyName in propertyNames) {
		if (!([propertyName isKindOfClass:[NSString class]] && entity.propertiesByName [propertyName])) { return nil; }
	}
	if (self = [super init]) {
		_entity = entity;
		_backing = [propertyNames copy];
	}
	return self;
}

- (NSArray <NSString *> *) arrayByValidatingObjectsAsPropertyNamesForEntity: (NSEntityDescription *) entity {
	if ([entity isEqual:_entity]) { return self; }
	return [super arrayByValidatingObjectsAsPropertyNamesForEntity:entity];
}

- (NSUInteger) count { return _backing.count; }
- (id) objectAtIndex: (NSUInteger) index { return _backing [index]; }
- (id) copyWithZone: (NSZone *) zone { return self; }
- (id) mutableCopyWithZone: (NSZone *) zone { return [_backing mutableCopyWithZone:zone]; }

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
