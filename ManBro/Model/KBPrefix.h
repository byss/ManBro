//
//  KBPrefix.h
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class KBDocument;
@interface KBPrefix: NSManagedObject

+ (instancetype) fetchOrCreatePrefixWithURL: (NSURL *) url context: (NSManagedObjectContext *) context;

@end

NS_ASSUME_NONNULL_END

#import "KBPrefix+CoreDataProperties.h"
