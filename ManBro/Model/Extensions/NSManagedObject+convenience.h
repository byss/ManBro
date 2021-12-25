//
//  NSManagedObject+convenience.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

#define KBVariables(...) _KBVariables (@"" #__VA_ARGS__, __VA_ARGS__)

NSDictionary <NSString *, id> *_KBVariables (NSString *keysString, ...);

@interface NSManagedObject (convenience)

+ (NSArray <NSString *> *__nullable) validatedArrayOfPropertyNames: (NSArray <NSString *> *) sourceArray;
+ (NSFetchRequest <__kindof NSManagedObject *> *) fetchRequestForObjectsWithValues: (NSArray *) values forPropertiesNamed: (NSArray <NSString *> *) propertyNames; 

+ (NSArray <__kindof NSManagedObject *> *) fetchObjectsWithValues: (NSArray *) values forPropertiesNamed: (NSArray <NSString *> *) propertyNames inContext: (NSManagedObjectContext *) context;
+ (instancetype __nullable) fetchUniqueObjectWithValues: (NSArray *) values forPropertiesNamed: (NSArray <NSString *> *) propertyNames inContext: (NSManagedObjectContext *) context;

- (id) valueForKey: (NSString *) key notifyObservers: (BOOL) notifyObservers;
- (id) valueForKey: (NSString *) key notifyObservers: (BOOL) notifyObservers transform: (id (^NS_NOESCAPE __nullable) (id)) transform;

- (void) setValue: (id) value forKey: (NSString *) key notifyObservers: (BOOL) notifyObservers;
- (void) setValue: (id) value forKey: (NSString *) key notifyObservers: (BOOL) notifyObservers additionalActions: (void (^NS_NOESCAPE __nullable) (void)) additionalActions;

@end

NS_ASSUME_NONNULL_END
