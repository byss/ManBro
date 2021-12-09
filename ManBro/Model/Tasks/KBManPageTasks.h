//
//  KBManPageTasks.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/10/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface KBManpathQueryTask: KBTask <NSArray <NSURL *> *>
@end

@interface KBGenerateHTMLTask: KBTask <NSData *>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithInputFileURL: (NSURL *) inputFileURL NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
