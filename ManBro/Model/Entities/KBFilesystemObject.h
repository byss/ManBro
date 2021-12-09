//
//  KBFilesystemObject.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

typedef id <NSObject, NSSecureCoding, NSCopying> NSURLGenerationIdentifier;

@interface KBFilesystemObject: NSManagedObject

@property (nonatomic, readonly, copy) NSURL *URL;
@property (nonatomic, strong) NSURLGenerationIdentifier generationIdentifier;

@end

NS_ASSUME_NONNULL_END
