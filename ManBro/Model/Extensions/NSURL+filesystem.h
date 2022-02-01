//
//  NSURL+filesystem.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/17/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (filesystem)

@property (nonatomic, readonly, class) NSArray <NSURLResourceKey> *readableRegularFileKeys;
@property (nonatomic, readonly, class) NSArray <NSURLResourceKey> *readableDirectoryKeys;

@property (nonatomic, readonly, getter = isReadableRegularFile) BOOL readableRegularFile;
@property (nonatomic, readonly, getter = isReadableDirectory) BOOL readableDirectory;

@property (nonatomic, readonly, nullable) NSString *fileSystemPath;

- (BOOL) isReadableRegularFile: (NSError *__autoreleasing *) error;
- (BOOL) isReadableDirectory: (NSError *__autoreleasing *) error;

- (void) checkHostResolvesToCurrentMachineWithCompletion: (void (^) (BOOL result, NSError *__nullable error)) completion;

@end

@interface NSDictionary (resourceValues)

@property (nonatomic, readonly, getter = isReadableRegularFile) BOOL readableRegularFile;
@property (nonatomic, readonly, getter = isReadableDirectory) BOOL readableDirectory;

@end

@interface NSURL (ManBro)

@property (nonatomic, readonly, class) NSArray <NSURLResourceKey> *readableDirectoryAndGenerationIdentifierKeys;
@property (nonatomic, readonly, class) NSArray <NSURLResourceKey> *readableRegularFileAndGenerationIdentifierKeys;

- (NSString *__nullable) manSectionName;
- (NSString *__nullable) manDocumentTitle;

@end

NS_ASSUME_NONNULL_END
