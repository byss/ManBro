//
//  NSPersistentContainer+sharedContainer.h
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSPersistentContainer (sharedContainer)

+ (instancetype) sharedContainer;

@end

@interface NSManagedObject (staleObjectsPredicate)

@property (nonatomic, readonly, nullable, class) NSPredicate *staleObjectsPredicate;

@end

NS_ASSUME_NONNULL_END
