//
//  KBSearchManager.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBSearchManager.h"

#import <stdatomic.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CoreData+logging.h"
#import "NSString+searchPredicateValue.h"
#import "NSPersistentContainer+sharedContainer.h"
#import "KBPrefix.h"
#import "KBSection.h"
#import "KBDocument.h"

@interface KBSearchQuery ()

@property (nonatomic, readonly) NSString *searchPredicateTextValue;

- (NSFetchRequest *) newFetchRequestForExactMatches;
- (NSFetchRequest *) newFetchRequestForPartialMatches;

@end

@interface KBFetchedResultsSectionInfo: NSObject <NSFetchedResultsSectionInfo>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithName: (NSString *) name objects: (NSArray *) objects NS_DESIGNATED_INITIALIZER;

@end

@interface KBSearchManager () {
	_Atomic NSUInteger _operationToken;
}

@property (nonatomic, readonly) NSUInteger operationToken;

@end

@implementation KBSearchManager

- (instancetype) init {
	return [self initWithContext:[[NSPersistentContainer sharedContainer] newBackgroundContext]];
}

- (instancetype) initWithContext: (NSManagedObjectContext *) context {
	if (!context) {
		return nil;
	}
	if (self = [super init]) {
		_context = context;
	}
	return self;
}

- (NSUInteger) operationToken {
	return atomic_load_explicit (&_operationToken, memory_order_acquire);
}

- (void) fetchDocumentsMatchingQuery: (KBSearchQuery *) searchQuery completion:(void (^)(NSArray <id <NSFetchedResultsSectionInfo>> *)) completion {
	NSUInteger const operationToken = atomic_fetch_add_explicit (&_operationToken, 1, memory_order_relaxed) + 1;
	if (!searchQuery) { return completion (@[]); }

	__block NSMutableArray <KBFetchedResultsSectionInfo *> *const result = [[NSMutableArray alloc] initWithCapacity:2];
	[self operation:operationToken runStep:^{
		KBFetchedResultsSectionInfo *const exactMatches = [[KBFetchedResultsSectionInfo alloc] initWithName:NSLocalizedString (@"Exact matches", @"") objects:[self.context executeFetchRequest:[searchQuery newFetchRequestForExactMatches]]];
		exactMatches ? [result addObject:exactMatches] : (void) 0;
	} completion:^{
		[self operation:operationToken runStep:^{
			KBFetchedResultsSectionInfo *const partialMatches = [[KBFetchedResultsSectionInfo alloc] initWithName:NSLocalizedString (@"Patial matches", @"") objects:[self.context executeFetchRequest:[searchQuery newFetchRequestForPartialMatches]]];
			partialMatches ? [result addObject:partialMatches] : (void) 0;
		} completion:^{
			completion (result);
		}];
	}];
}

- (void) operation: (NSUInteger) operationToken runStep: (void (^) (void)) operationStep completion: (void (^) (void)) completionBlock {
	[self.context performBlock:^{
		if (self.operationToken == operationToken) { operationStep (); }
		if (self.operationToken == operationToken) { completionBlock (); }
	}];
}

@end

@interface KBSearchQueryI: KBSearchQuery
@end

@interface KBMutableSearchQuery ()

- (instancetype) initWithSearchQuery: (KBSearchQuery *) searchQuery;

@end

@interface KBSearchQuery () {
@protected
	NSString *_text, *_searchPredicateTextValue;
}

@end

@interface NSComparisonPredicate (convenience)

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath;
- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName;

@end

@implementation KBFetchedResultsSectionInfo

@synthesize name = _name, objects = _objects;

- (instancetype) initWithName: (NSString *) name objects: (NSArray *) objects {
	if (!(objects.count && name.length)) {
		return nil;
	}
	if (self = [super init]) {
		_name = [name copy];
		_objects = [objects copy];
	}
	return self;
}

- (NSUInteger) numberOfObjects {
	return self.objects.count;
}

- (NSString *) indexTitle {
	return self.name;
}

@end

extern char const _KBSearchQueryClass asm ("_OBJC_CLASS_$_KBSearchQuery");
static Class __unsafe_unretained const KBSearchQueryClass = (__bridge Class) (void const *) &_KBSearchQueryClass;
extern char const _KBSearchQueryClass NS_UNAVAILABLE;

@implementation KBSearchQuery

@dynamic prefixes, sections;

+ (instancetype) allocWithZone: (NSZone *) zone {
	return (self == KBSearchQueryClass) ? [KBSearchQueryI allocWithZone:zone] : [super allocWithZone:zone];
}

- (instancetype) init {
	return [self initWithText:(id __nonnull) nil];
}

- (instancetype) initWithText: (NSString *) text {
	return [super init];
}

- (BOOL) isEqual: (id) object {
	return [object isKindOfClass:KBSearchQueryClass] && [self isEqualToSearchQuery:object];
}

- (BOOL) isEqualToSearchQuery: (KBSearchQuery *) searchQuery {
#define NSEqualsOrNils(_lhs, _rhs) _NSEqualsOrNils (__COUNTER__, _lhs, _rhs)
#define _NSEqualsOrNils(_ctr, _lhs, _rhs) ({ \
	typeof (_lhs) lhs ## _ctr = (_lhs); \
	typeof (_rhs) rhs ## _ctr = (_rhs); \
	BOOL result; \
	if (lhs ## _ctr) { \
		result = [lhs ## _ctr isEqual:rhs ## _ctr]; \
	} else { \
		result = !rhs ## _ctr; \
	} \
	result; \
})
	return [self.searchPredicateTextValue isEqualToString:searchQuery.searchPredicateTextValue] && NSEqualsOrNils (self.prefixes, searchQuery.prefixes) && NSEqualsOrNils (self.sections, searchQuery.sections);
#undef _NSEqualsOrNils
#undef NSEqualsOrNils
}

- (NSUInteger) hash {
	return self.searchPredicateTextValue.hash ^ (self.prefixes.hash * 7) ^ (self.sections.hash * 17);
}

- (id) mutableCopyWithZone: (NSZone *) zone {
	return [[KBMutableSearchQuery allocWithZone:zone] initWithSearchQuery:self];
}

- (NSFetchRequest *) newFetchRequestWithTitleSubpredicateTemplate: (NSPredicate *) titleSubpredicateTemplate {
	static NSPredicate *singlePrefixSubpredicateTemplate, *prefixesSubpredicateTemplate, *singleSectionSubpredicateTemplate, *sectionsSubpredicateTemplate;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		singlePrefixSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSEqualToPredicateOperatorType modifier:NSDirectPredicateModifier options:0 forKeyPath:@"section.prefix" variableName:@"prefix"];
		prefixesSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSInPredicateOperatorType modifier:NSDirectPredicateModifier options:0 forKeyPath:@"section.prefix" variableName:@"prefixes"];
		singleSectionSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSEqualToPredicateOperatorType modifier:NSDirectPredicateModifier options:0 forKeyPath:@"section"];
		sectionsSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSInPredicateOperatorType modifier:NSDirectPredicateModifier options:0 forKeyPath:@"section" variableName:@"sections"];
	});
	
	NSFetchRequest *const result = [KBDocument fetchRequest];
	NSPredicate *const titleSubpredicate = [titleSubpredicateTemplate predicateWithSubstitutionVariables:@{@"title": self.searchPredicateTextValue}];
	if (self.prefixes || self.sections) {
		NSMutableArray <NSPredicate *> *const subpredicates = [[NSMutableArray alloc] initWithCapacity:3];
		[subpredicates addObject:titleSubpredicate];
		NSMutableArray <NSString *> *const propertiesToGroupBy = [[NSMutableArray alloc] initWithCapacity:2];
		switch (self.sections.count) {
			case 0:
				break;
			case 1:
				[subpredicates addObject:[singleSectionSubpredicateTemplate predicateWithSubstitutionVariables:@{@"section": self.sections.anyObject}]];
				break;
			default:
				[subpredicates addObject:[sectionsSubpredicateTemplate predicateWithSubstitutionVariables:@{@"sections": self.sections}]];
				[propertiesToGroupBy addObject:@"section"];
		}
		switch (self.prefixes.count) {
			case 0:
				break;
			case 1:
				[subpredicates addObject:[singlePrefixSubpredicateTemplate predicateWithSubstitutionVariables:@{@"prefix": self.prefixes.anyObject}]];
				break;
			default:
				[subpredicates addObject:[prefixesSubpredicateTemplate predicateWithSubstitutionVariables:@{@"prefixes": self.prefixes}]];
				[propertiesToGroupBy addObject:@"section.prefix"];
		}
		
		result.resultType = NSDictionaryResultType;
		result.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:subpredicates];
		propertiesToGroupBy.count ? result.propertiesToGroupBy = propertiesToGroupBy : (void) 0;
	} else {
		result.resultType = NSManagedObjectResultType;
		result.predicate = titleSubpredicate;
	}
	result.relationshipKeyPathsForPrefetching = @[@"section", @"section.prefix"];
	return result;
}

- (NSFetchRequest *) newFetchRequestForExactMatches {
	static NSPredicate *titleSubpredicateTemplate;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		titleSubpredicateTemplate = [self titleComparisonPredicateWithOperatorType:NSEqualToPredicateOperatorType];
	});
	return [self newFetchRequestWithTitleSubpredicateTemplate:titleSubpredicateTemplate];
}

- (NSFetchRequest *) newFetchRequestForPartialMatches {
	static NSPredicate *titleSubpredicateTemplate;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		titleSubpredicateTemplate = [self titleComparisonPredicateWithOperatorType:NSContainsPredicateOperatorType];
	});
	NSFetchRequest *const result = [self newFetchRequestWithTitleSubpredicateTemplate:titleSubpredicateTemplate];
	if (result.resultType == NSManagedObjectResultType) {
		result.fetchBatchSize = 25;
	}
	return result;
}

- (NSPredicate *) titleComparisonPredicateWithOperatorType: (NSPredicateOperatorType) operatorType {
	return [[NSComparisonPredicate alloc] initTemplateWithType:operatorType modifier:NSDirectPredicateModifier options:NSNormalizedPredicateOption forKeyPath:@"normalizedTitle" variableName:@"title"];
}

@end

@interface KBSearchQueryI ()

@property (nonatomic, copy, nullable) NSFetchRequest *fetchRequestForExactMatches;
@property (nonatomic, copy, nullable) NSFetchRequest *fetchRequestForPartialMatches;

@end

@implementation KBSearchQueryI

@synthesize prefixes = _prefixes, sections = _sections;

static NSFetchRequest *KBSearchQueryCachingFetchRequestGetter (KBSearchQueryI *const self, SEL _cmd) {
	NSCParameterAssert ([NSStringFromSelector (_cmd) hasPrefix:@"newF"]);
	NSString *const cachedValueKeyPath = [@"f" stringByAppendingString:[NSStringFromSelector (_cmd) substringFromIndex:4]];
	NSFetchRequest *result = [self valueForKeyPath:cachedValueKeyPath];
	if (!result) {
		result = ((NSFetchRequest *(*)(struct objc_super *, SEL)) objc_msgSendSuper) ((struct objc_super []) {{ .receiver = self, .super_class = KBSearchQueryClass }}, _cmd);
		[self setValue:result forKeyPath:cachedValueKeyPath];
	}
	return result;
}

+ (void) initialize {
	if (self == [KBSearchQueryI class]) {
		char const cachingFetchRequestGetterTypes [] = { _C_ID, _C_ID, _C_SEL, '\0' };
		IMP const cachingFetchRequestGetter = (IMP) KBSearchQueryCachingFetchRequestGetter;
		class_addMethod (self, @selector (newFetchRequestForExactMatches), cachingFetchRequestGetter, cachingFetchRequestGetterTypes);
		class_addMethod (self, @selector (newFetchRequestForPartialMatches), cachingFetchRequestGetter, cachingFetchRequestGetterTypes);
	}
}

- (instancetype) initWithText: (NSString *) text {
	NSString *const searchPredicateTextValue = [text stringByPreparingForCaseInsensitiveComparisonPredicates];
	if (!searchPredicateTextValue) {
		return nil;
	}
	if (self = [super initWithText:(id __nonnull) nil]) {
		_text = [text copy];
		_searchPredicateTextValue = searchPredicateTextValue;
	}
	return self;
}

- (instancetype) initWithSearchQuery: (KBSearchQuery *) searchQuery {
	NSParameterAssert (searchQuery);
	if (self = [super initWithText:(id __nonnull) nil]) {
		_text = [searchQuery.text copy];
		_searchPredicateTextValue = [searchQuery.searchPredicateTextValue copy];
		_prefixes = [searchQuery.prefixes copy];
		_sections = [searchQuery.sections copy];
	}
	return self;
}

- (id) copyWithZone: (NSZone *) zone {
	return self;
}

@end

@implementation KBMutableSearchQuery

@dynamic text;
@synthesize prefixes = _prefixes, sections = _sections;

+ (instancetype) new {
	return [[self allocWithZone:nil] initWithSearchQuery:nil];
}

- (instancetype) init {
	return [self initWithSearchQuery:nil];
}

- (instancetype) initWithSearchQuery: (KBSearchQuery *) searchQuery {
	NSParameterAssert (searchQuery);
	if (self = [super initWithText:(id __nonnull) nil]) {
		self.text = searchQuery.text;
		self.prefixes = searchQuery.prefixes;
		self.sections = searchQuery.sections;
	}
	return self;
}

- (id) copyWithZone: (NSZone *) zone {
	return [[KBSearchQueryI allocWithZone:zone] initWithSearchQuery:self];
}

- (NSString *) searchPredicateTextValue {
	if (!_searchPredicateTextValue) {
		_searchPredicateTextValue = [self.text stringByPreparingForCaseInsensitiveComparisonPredicates];
	}
	return _searchPredicateTextValue;
}

- (void) setText: (NSString *) text {
	_text = [text copy];
	_searchPredicateTextValue = nil;
}

- (void) setPrefixes: (NSSet <KBPrefix *> *) prefixes {
	_prefixes = prefixes.count ? [prefixes copy] : nil;
}

- (void) setSections: (NSSet <KBSection *> *) sections {
	_sections = sections.count ? [sections copy] : nil;
}

- (NSFetchRequest *) newFetchRequestForExactMatches {
	NSParameterAssert (self.searchPredicateTextValue.length);
	return [super newFetchRequestForExactMatches];
}

- (NSFetchRequest *) newFetchRequestForPartialMatches {
	NSParameterAssert (self.searchPredicateTextValue.length);
	return [super newFetchRequestForPartialMatches];
}

@end

@implementation NSComparisonPredicate (convenience)

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath {
	return [self initTemplateWithType:type modifier:modifier options:options forKeyPath:keyPath variableName:keyPath];
}

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName {
	return [self initWithLeftExpression:[NSExpression expressionForKeyPath:keyPath] rightExpression:[NSExpression expressionForVariable:variableName] modifier:modifier type:type options:options];
}

@end
