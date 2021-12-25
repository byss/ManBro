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
#import "NSComparisonPredicate+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"
#import "KBPrefix.h"
#import "KBSection.h"
#import "KBDocumentMeta.h"

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

- (NSArray <KBDocumentMeta *> *) executeDocumentsFetchRequest: (NSFetchRequest *) request {
	return [[self.context executeFetchRequest:request] sortedArrayUsingComparator:^NSComparisonResult (KBDocumentMeta *lhs, KBDocumentMeta *rhs) {
		NSUInteger const lhsPrefixPrio = lhs.prefix.priority, rhsPrefixPrio = rhs.prefix.priority;
		if (lhsPrefixPrio < rhsPrefixPrio) { return NSOrderedAscending; }
		if (lhsPrefixPrio > rhsPrefixPrio) { return NSOrderedDescending; }
		NSComparisonResult const sectionNameComparisonResult = [lhs.section.name localizedStandardCompare:rhs.section.name];
		if (sectionNameComparisonResult != NSOrderedSame) { return sectionNameComparisonResult; }
		NSUInteger const lhsTitleLength = lhs.title.length, rhsTitleLength = rhs.title.length;
		if (lhsTitleLength < rhsTitleLength) { return NSOrderedAscending; }
		if (lhsTitleLength > rhsTitleLength) { return NSOrderedDescending; }
		return [lhs.title localizedStandardCompare:rhs.title];
	}];
}

- (NSArray <id <NSFetchedResultsSectionInfo>> *) fetchDocumentsMatchingQuery: (KBSearchQuery *) searchQuery {
	id <NSFetchedResultsSectionInfo> result [] = { nil, nil }, __strong *last = result;
	(*last = [self fetchExactMatchesForQuery:searchQuery]) ? last++ : (void) 0;
	(*last = [self fetchPartialMatchesForQuery:searchQuery]) ? last++ : (void) 0;
	return [[NSArray alloc] initWithObjects:result count:last - result];
}

- (void) fetchDocumentsMatchingQuery: (KBSearchQuery *) searchQuery completion:(void (^)(NSArray <id <NSFetchedResultsSectionInfo>> *)) completion {
	NSUInteger const operationToken = atomic_fetch_add_explicit (&_operationToken, 1, memory_order_relaxed) + 1;
	if (!(searchQuery = [searchQuery copy])) { return completion (@[]); }

	__block id <NSFetchedResultsSectionInfo> exactMatches, partialMatches;
	[self operation:operationToken runStep:^{ exactMatches = [self fetchExactMatchesForQuery:searchQuery]; }];
	[self operation:operationToken runStep:^{ partialMatches = [self fetchPartialMatchesForQuery:searchQuery]; }];
	[self operation:operationToken runStep:^{
		NSMutableArray <id <NSFetchedResultsSectionInfo>> *const result = [[NSMutableArray alloc] initWithCapacity:2];
		exactMatches ? [result addObject:exactMatches] : (void) 0;
		partialMatches ? [result addObject:partialMatches] : (void) 0;
		completion ([[NSArray alloc] initWithArray:result]);
	}];
}

- (void) operation: (NSUInteger) operationToken runStep: (dispatch_block_t) operationStep {
	[self operation:operationToken runStep:operationStep completion:NULL];
}

- (void) operation: (NSUInteger) operationToken runStep: (dispatch_block_t) operationStep completion: (dispatch_block_t) completionBlock {
	[self operation:operationToken runAction:operationStep];
	completionBlock ? [self operation:operationToken runAction:completionBlock] : (void) 0;
}

- (void) operation: (NSUInteger) operationToken runAction: (dispatch_block_t) action {
	__weak typeof (self) weakSelf = self;
	[self.context performBlock:^{
		typeof (self) self = weakSelf;
		if (self && (self.operationToken == operationToken)) { action (); }
	}];
}

- (id <NSFetchedResultsSectionInfo>) fetchExactMatchesForQuery: (KBSearchQuery *) query {
	return [[KBFetchedResultsSectionInfo alloc] initWithName:NSLocalizedString (@"Exact matches", @"") objects:[self executeDocumentsFetchRequest:[query newFetchRequestForExactMatches]]];
}

- (id <NSFetchedResultsSectionInfo>) fetchPartialMatchesForQuery: (KBSearchQuery *) query {
	if (!query.partialMatchingAllowed) { return nil; }
	return [[KBFetchedResultsSectionInfo alloc] initWithName:NSLocalizedString (@"Partial matches", @"") objects:[self executeDocumentsFetchRequest:[query newFetchRequestForPartialMatches]]];
}

@end

@interface KBSearchQueryI: KBSearchQuery
@end

@interface KBMutableSearchQuery ()

- (instancetype) initWithText: (NSString *__nullable) text;
- (instancetype) initWithSearchQuery: (KBSearchQuery *) searchQuery;

@end

@interface KBSearchQuery () {
@protected
	NSString *_text, *_searchPredicateTextValue;
}

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

@dynamic prefixes, sections, partialMatchingAllowed;

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
	return [self.searchPredicateTextValue isEqualToString:searchQuery.searchPredicateTextValue] && NSEqualsOrNils (self.prefixes, searchQuery.prefixes) && NSEqualsOrNils (self.sections, searchQuery.sections) && (!self.partialMatchingAllowed == !searchQuery.partialMatchingAllowed);
#undef _NSEqualsOrNils
#undef NSEqualsOrNils
}

- (NSUInteger) hash {
	return self.searchPredicateTextValue.hash ^ (self.prefixes.hash * 7) ^ (self.sections.hash * 17) ^ (self.partialMatchingAllowed ? 0 : 31);
}

- (id) mutableCopyWithZone: (NSZone *) zone {
	return [[KBMutableSearchQuery allocWithZone:zone] initWithSearchQuery:self];
}

- (NSFetchRequest *) newFetchRequestWithTitleSubpredicateTemplate: (NSPredicate *) titleSubpredicateTemplate {
	static NSPredicate *singlePrefixSubpredicateTemplate, *prefixesSubpredicateTemplate, *singleSectionSubpredicateTemplate, *sectionsSubpredicateTemplate;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		singlePrefixSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSEqualToPredicateOperatorType forKeyPath:@"section.prefix" variableName:@"prefix"];
		prefixesSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSInPredicateOperatorType forKeyPath:@"section.prefix" variableName:@"prefixes"];
		singleSectionSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSEqualToPredicateOperatorType forKeyPath:@"section"];
		sectionsSubpredicateTemplate = [[NSComparisonPredicate alloc] initTemplateWithType:NSInPredicateOperatorType forKeyPath:@"section" variableName:@"sections"];
	});
	
	NSFetchRequest *const result = [KBDocumentMeta fetchRequest];
	result.resultType = NSManagedObjectResultType;
	NSPredicate *const titleSubpredicate = [titleSubpredicateTemplate predicateWithSubstitutionVariables:@{@"title": self.searchPredicateTextValue}];
	if (self.prefixes || self.sections) {
		NSMutableArray <NSPredicate *> *const subpredicates = [[NSMutableArray alloc] initWithCapacity:3];
		[subpredicates addObject:titleSubpredicate];
		switch (self.sections.count) {
			case 0:
				break;
			case 1:
				[subpredicates addObject:[singleSectionSubpredicateTemplate predicateWithSubstitutionVariables:@{@"section": self.sections.anyObject}]];
				break;
			default:
				[subpredicates addObject:[sectionsSubpredicateTemplate predicateWithSubstitutionVariables:@{@"sections": self.sections}]];
		}
		switch (self.prefixes.count) {
			case 0:
				break;
			case 1:
				[subpredicates addObject:[singlePrefixSubpredicateTemplate predicateWithSubstitutionVariables:@{@"prefix": self.prefixes.anyObject}]];
				break;
			default:
				[subpredicates addObject:[prefixesSubpredicateTemplate predicateWithSubstitutionVariables:@{@"prefixes": self.prefixes}]];
		}
		result.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:subpredicates];
	} else {
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
		NSMutableArray <NSPredicate *> *const subpredicates = [[NSMutableArray alloc] initWithCapacity:2];
		[subpredicates addObject:[self titleComparisonPredicateWithOperatorType:NSContainsPredicateOperatorType]];
		[subpredicates addObject:[self titleComparisonPredicateWithOperatorType:NSNotEqualToPredicateOperatorType]];
		titleSubpredicateTemplate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:subpredicates];
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

@synthesize prefixes = _prefixes, sections = _sections, partialMatchingAllowed = _partialMatchingAllowed;

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
		_partialMatchingAllowed = YES;
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
		_partialMatchingAllowed = searchQuery.partialMatchingAllowed;
	}
	return self;
}

- (id) copyWithZone: (NSZone *) zone {
	return self;
}

@end

@implementation KBMutableSearchQuery

@dynamic text;
@synthesize prefixes = _prefixes, sections = _sections, partialMatchingAllowed = _partialMatchingAllowed;

+ (instancetype) new {
	return [(KBMutableSearchQuery *) [self allocWithZone:nil] initWithText:nil];
}

- (instancetype) init {
	return [self initWithText:nil];
}

- (instancetype) initWithText: (NSString *) text {
	if (self = [super initWithText:text]) {
		self.text = text;
		self.partialMatchingAllowed = YES;
	}
	return self;
}

- (instancetype) initWithSearchQuery: (KBSearchQuery *) searchQuery {
	NSParameterAssert (searchQuery);
	if (self = [super initWithText:searchQuery.text]) {
		self.text = searchQuery.text;
		self.prefixes = searchQuery.prefixes;
		self.sections = searchQuery.sections;
		self.partialMatchingAllowed = searchQuery.partialMatchingAllowed;
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
