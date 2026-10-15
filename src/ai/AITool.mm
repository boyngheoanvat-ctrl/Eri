#import "AITool.h"
#import "IL2CPPResolver.h"
#import "GameFingerprint.h"

static NSMutableDictionary<NSString *, AITool *> *gTools = nil;

@implementation AITool

+ (instancetype)toolWithName:(NSString *)name description:(NSString *)desc
                  parameters:(NSDictionary *)params handler:(id (^)(NSDictionary *))handler {
    AITool *t = [[AITool alloc] init];
    t.name = name; t.toolDescription = desc; t.parameters = params; t.handler = handler;
    return t;
}

+ (NSArray<AITool *> *)allTools { return gTools.allValues ?: @[]; }
+ (AITool *)toolNamed:(NSString *)name { return gTools[name]; }

+ (void)registerTool:(AITool *)tool {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ gTools = [NSMutableDictionary dictionary]; });
    if (tool.name) gTools[tool.name] = tool;
}

+ (void)registerAll {
    [self registerTool:[AITool toolWithName:@"find_concept"
        description:@"Tim method hack theo KHAI NIEM. AI TU DONG nhan dien game va match method phu hop. concept: map, speed, damage, health, mana, money, cooldown, ammo, level"
        parameters:@{@"type": @"object", @"properties": @{
            @"concept": @{@"type": @"string"}}, @"required": @[@"concept"]}
        handler:^id(NSDictionary *args) {
            [[IL2CPPResolver shared] attachCurrentThread];
            return [AITool findConcept:args[@"concept"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"search_classes"
        description:@"Tim class IL2CPP theo keyword (ten class hoac namespace). Vi du: Hero, Player, Skill, Item, Camera, Entity."
        parameters:@{@"type": @"object", @"properties": @{
            @"keyword": @{@"type": @"string"}}, @"required": @[@"keyword"]}
        handler:^id(NSDictionary *args) {
            [[IL2CPPResolver shared] attachCurrentThread];
            return [AITool searchClasses:args[@"keyword"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"dump_class_runtime"
        description:@"Xem chi tiet 1 class: field (ten, offset), method (ten, RVA)."
        parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"}}, @"required": @[@"class_name"]}
        handler:^id(NSDictionary *args) {
            [[IL2CPPResolver shared] attachCurrentThread];
            return [AITool dumpClassRuntime:args[@"class_name"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"find_method_in_class"
        description:@"Tim method trong 1 class theo keyword. Vi du: class=Hero, keyword=speed."
        parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"},
            @"keyword": @{@"type": @"string"}},
            @"required": @[@"class_name", @"keyword"]}
        handler:^id(NSDictionary *args) {
            [[IL2CPPResolver shared] attachCurrentThread];
            return [AITool findMethodInClass:args[@"class_name"] ?: @""
                                     keyword:args[@"keyword"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"find_method_global"
        description:@"Tim method tren TOAN BO assembly theo keyword. Dung khi khong biet class. Vi du: keyword=CanSight."
        parameters:@{@"type": @"object", @"properties": @{
            @"keyword": @{@"type": @"string"},
            @"max_results": @{@"type": @"integer"}},
            @"required": @[@"keyword"]}
        handler:^id(NSDictionary *args) {
            [[IL2CPPResolver shared] attachCurrentThread];
            return [AITool findMethodGlobal:args[@"keyword"] ?: @""
                                 maxResults:[args[@"max_results"] integerValue] ?: 10];
        }]];

    [self registerTool:[AITool toolWithName:@"find_field_in_class"
        description:@"Tim field trong class theo keyword. Vi du: class=ShowEntity, keyword=fighter."
        parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"},
            @"keyword": @{@"type": @"string"}},
            @"required": @[@"class_name", @"keyword"]}
        handler:^id(NSDictionary *args) {
            [[IL2CPPResolver shared] attachCurrentThread];
            return [AITool findFieldInClass:args[@"class_name"] ?: @""
                                    keyword:args[@"keyword"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"find_classes_by_method"
        description:@"Tim class nao co method ten cu the. Vi du: method=CanSight."
        parameters:@{@"type": @"object", @"properties": @{
            @"method_name": @{@"type": @"string"}}, @"required": @[@"method_name"]}
        handler:^id(NSDictionary *args) {
            [[IL2CPPResolver shared] attachCurrentThread];
            return [AITool findClassesByMethod:args[@"method_name"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"read_file"
        description:@"Grep file dump (script.json / dump.cs / il2cpp.h)."
        parameters:@{@"type": @"object", @"properties": @{
            @"filename": @{@"type": @"string"},
            @"keyword": @{@"type": @"string"}}, @"required": @[@"filename"]}
        handler:^id(NSDictionary *args) {
            return [AITool readFile:args[@"filename"] ?: @""
                            keyword:args[@"keyword"] ?: @""];
        }]];
}

- (NSDictionary *)openAISchema {
    return @{@"type": @"function", @"function": @{
        @"name": self.name ?: @"", @"description": self.toolDescription ?: @"",
        @"parameters": self.parameters ?: @{@"type": @"object", @"properties": @{}}}};
}

#pragma mark - Helpers

+ (BOOL)isSystemName:(NSString *)name {
    if (name.length == 0) return YES;
    NSString *l = name.lowercaseString;
    NSArray<NSString *> *skip = @[
        @"util", @"helper", @"config", @"setting", @"debug",
        @"editor", @"<", @"system.", @"unityengine.",
        @"mscorlib", @"newtonsoft", @"system.core",
    ];
    for (NSString *s in skip) {
        if ([l containsString:s]) return YES;
    }
    return NO;
}

+ (NSUInteger)classPriority:(NSString *)className {
    if (className.length == 0) return 0;
    if ([className isEqualToString:@"ShowEntity"])       return 100;
    if ([className isEqualToString:@"LogicFighter"])     return 90;
    if ([className isEqualToString:@"Hero"])             return 80;
    if ([className isEqualToString:@"Player"])           return 80;
    if ([className isEqualToString:@"BattleManager"])    return 70;
    if ([className isEqualToString:@"Camera"])           return 70;
    NSString *l = className.lowercaseString;
    if ([l containsString:@"entity"])   return 60;
    if ([l containsString:@"fighter"])  return 60;
    if ([l containsString:@"hero"])     return 60;
    if ([l containsString:@"player"])   return 60;
    if ([l containsString:@"skill"])    return 55;
    if ([l containsString:@"item"])     return 55;
    if ([l containsString:@"camera"])   return 55;
    if ([l containsString:@"manager"])  return 40;
    return 10;
}

#pragma mark - find_concept

+ (id)findConcept:(NSString *)concept {
    if (concept.length == 0) return @{@"error": @"required"};

    GameFingerprint *fp = [GameFingerprint shared];
    NSString *game = [fp detectedGame];

    NSArray<NSDictionary *> *results = [fp findMethodsForConcept:concept
                                                       maxResults:5];

    return @{
        @"game": game,
        @"concept": concept,
        @"count": @(results.count),
        @"results": results,
    };
}

#pragma mark - search_classes

+ (id)searchClasses:(NSString *)keyword {
    if (keyword.length == 0) return @{@"error": @"required"};
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return @{@"error": @"No domain"};

    NSString *lower = keyword.lowercaseString;
    NSMutableArray *results = [NSMutableArray array];

    @try {
        for (int a = 0; a < MIN((int)domain->assembly_count, 8) && results.count < 30; a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count && results.count < 30; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *name = [NSString stringWithUTF8String:cname];
                    if (!name) continue;
                    if ([self isSystemName:name]) continue;

                    const char *cns = [r class_get_namespace:klass];
                    NSString *ns = (cns && [NSString stringWithUTF8String:cns])
                                  ? [NSString stringWithUTF8String:cns] : @"";

                    if ([name.lowercaseString containsString:lower] ||
                        [ns.lowercaseString containsString:lower]) {
                        [results addObject:@{
                            @"name": name,
                            @"namespace": ns ?: @"",
                            @"priority": @([self classPriority:name]),
                        }];
                    }
                }
            }
        }
    } @catch (NSException *e) { return @{@"error": e.reason ?: @"Exception"}; }

    [results sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"priority"] compare:a[@"priority"]];
    }];

    return @{@"count": @(results.count), @"classes": results};
}

#pragma mark - dump_class_runtime

+ (id)dumpClassRuntime:(NSString *)className {
    if (className.length == 0) return @{@"error": @"required"};
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    Il2CppClass *klass = NULL;
    for (int a = 0; a < domain->assembly_count && !klass; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image) continue;
        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k) continue;
            const char *cn = [r class_get_name:k];
            if (!cn) continue;
            NSString *n = [NSString stringWithUTF8String:cn];
            if (n && [n isEqualToString:className]) { klass = k; break; }
        }
    }
    if (!klass) return @{@"error": [NSString stringWithFormat:@"Class '%@' not found", className]};

    NSMutableArray *fields = [NSMutableArray array];
    uint16_t fCount = 0;
    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];
    for (uint16_t j = 0; j < fCount && fields.count < 100; j++) {
        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
        if (!f) continue;
        const char *fn = [r field_get_name:f];
        int32_t off = [r field_get_offset:f];
        if (fn) {
            [fields addObject:@{
                @"name": [NSString stringWithUTF8String:fn],
                @"offset": [NSString stringWithFormat:@"0x%X", off],
            }];
        }
    }

    NSMutableArray *methods = [NSMutableArray array];
    uint16_t mCount = 0;
    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
    for (uint16_t j = 0; j < mCount && methods.count < 100; j++) {
        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
        if (!m) continue;
        const char *mn = [r method_get_name:m];
        void *ptr = [r method_get_pointer:m];
        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
        uint32_t token = [r method_get_token:m];
        if (mn) {
            [methods addObject:@{
                @"name": [NSString stringWithUTF8String:mn],
                @"rva": [NSString stringWithFormat:@"0x%llX", rva],
                @"token": [NSString stringWithFormat:@"0x%X", token],
            }];
        }
    }

    return @{
        @"class": className,
        @"field_count": @(fields.count),
        @"method_count": @(methods.count),
        @"fields": fields,
        @"methods": methods,
    };
}

#pragma mark - find_method_in_class

+ (id)findMethodInClass:(NSString *)className keyword:(NSString *)keyword {
    if (className.length == 0 || keyword.length == 0)
        return @{@"error": @"required"};

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    Il2CppClass *klass = NULL;
    for (int a = 0; a < domain->assembly_count && !klass; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image) continue;
        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k) continue;
            const char *cn = [r class_get_name:k];
            if (!cn) continue;
            NSString *n = [NSString stringWithUTF8String:cn];
            if (n && [n isEqualToString:className]) { klass = k; break; }
        }
    }
    if (!klass) return @{@"error": [NSString stringWithFormat:@"Class '%@' not found", className]};

    NSString *lowerKw = keyword.lowercaseString;
    NSMutableArray *found = [NSMutableArray array];

    uint16_t mCount = 0;
    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
    for (uint16_t j = 0; j < mCount; j++) {
        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
        if (!m) continue;
        const char *mn = [r method_get_name:m];
        if (!mn) continue;
        NSString *mName = [NSString stringWithUTF8String:mn];
        if (!mName) continue;
        if (![mName.lowercaseString containsString:lowerKw]) continue;

        void *ptr = [r method_get_pointer:m];
        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
        [found addObject:@{
            @"name": mName,
            @"rva": [NSString stringWithFormat:@"0x%llX", rva],
        }];
    }

    return @{@"class": className, @"keyword": keyword,
             @"count": @(found.count), @"methods": found};
}

#pragma mark - find_method_global

+ (id)findMethodGlobal:(NSString *)keyword maxResults:(NSInteger)maxResults {
    if (keyword.length == 0) return @{@"error": @"required"};
    if (maxResults <= 0) maxResults = 10;
    if (maxResults > 50) maxResults = 50;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    NSString *lowerKw = keyword.lowercaseString;
    NSMutableArray *found = [NSMutableArray array];

    @try {
        for (int a = 0; a < MIN((int)domain->assembly_count, 5); a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count && found.count < (NSUInteger)maxResults * 3; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *className = [NSString stringWithUTF8String:cname];
                    if (!className) continue;
                    if ([self isSystemName:className]) continue;

                    NSUInteger cPriority = [self classPriority:className];

                    uint16_t mCount = 0;
                    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
                    for (uint16_t j = 0; j < mCount; j++) {
                        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                        if (!m) continue;
                        const char *mn = [r method_get_name:m];
                        if (!mn) continue;
                        NSString *mName = [NSString stringWithUTF8String:mn];
                        if (!mName) continue;
                        if (![mName.lowercaseString containsString:lowerKw]) continue;

                        void *ptr = [r method_get_pointer:m];
                        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;

                        NSUInteger score = cPriority;
                        if ([mName isEqualToString:keyword]) score += 100;
                        else if ([mName.lowercaseString hasPrefix:@"get_"]) score += 30;
                        else if ([mName.lowercaseString hasPrefix:@"set_"]) score += 25;

                        [found addObject:@{
                            @"class": className,
                            @"method": mName,
                            @"rva": [NSString stringWithFormat:@"0x%llX", rva],
                            @"score": @(score),
                        }];
                    }
                }
            }
        }
    } @catch (NSException *e) { return @{@"error": e.reason ?: @"Exception"}; }

    [found sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];

    if (found.count > (NSUInteger)maxResults) {
        [found removeObjectsInRange:NSMakeRange(maxResults, found.count - maxResults)];
    }

    return @{@"keyword": keyword, @"count": @(found.count), @"methods": found};
}

#pragma mark - find_field_in_class

+ (id)findFieldInClass:(NSString *)className keyword:(NSString *)keyword {
    if (className.length == 0 || keyword.length == 0)
        return @{@"error": @"required"};

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    Il2CppClass *klass = NULL;
    for (int a = 0; a < domain->assembly_count && !klass; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image) continue;
        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k) continue;
            const char *cn = [r class_get_name:k];
            if (!cn) continue;
            NSString *n = [NSString stringWithUTF8String:cn];
            if (n && [n isEqualToString:className]) { klass = k; break; }
        }
    }
    if (!klass) return @{@"error": [NSString stringWithFormat:@"Class '%@' not found", className]};

    NSString *lowerKw = keyword.lowercaseString;
    NSMutableArray *found = [NSMutableArray array];

    uint16_t fCount = 0;
    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];
    for (uint16_t j = 0; j < fCount; j++) {
        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
        if (!f) continue;
        const char *fn = [r field_get_name:f];
        if (!fn) continue;
        NSString *fName = [NSString stringWithUTF8String:fn];
        if (!fName) continue;
        if (![fName.lowercaseString containsString:lowerKw]) continue;

        int32_t off = [r field_get_offset:f];
        [found addObject:@{
            @"name": fName,
            @"offset": [NSString stringWithFormat:@"0x%X", off],
        }];
    }

    return @{@"class": className, @"keyword": keyword,
             @"count": @(found.count), @"fields": found};
}

#pragma mark - find_classes_by_method

+ (id)findClassesByMethod:(NSString *)methodName {
    if (methodName.length == 0) return @{@"error": @"required"};

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    NSMutableArray *found = [NSMutableArray array];

    @try {
        for (int a = 0; a < MIN((int)domain->assembly_count, 5); a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count && found.count < 20; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *className = [NSString stringWithUTF8String:cname];
                    if (!className) continue;
                    if ([self isSystemName:className]) continue;

                    uint16_t mCount = 0;
                    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
                    for (uint16_t j = 0; j < mCount; j++) {
                        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                        if (!m) continue;
                        const char *mn = [r method_get_name:m];
                        if (!mn) continue;
                        NSString *mName = [NSString stringWithUTF8String:mn];
                        if (![mName isEqualToString:methodName]) continue;

                        void *ptr = [r method_get_pointer:m];
                        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                        [found addObject:@{
                            @"class": className,
                            @"method": mName,
                            @"rva": [NSString stringWithFormat:@"0x%llX", rva],
                            @"priority": @([self classPriority:className]),
                        }];
                        break;
                    }
                }
            }
        }
    } @catch (NSException *e) { return @{@"error": e.reason ?: @"Exception"}; }

    [found sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"priority"] compare:a[@"priority"]];
    }];

    return @{@"method": methodName, @"count": @(found.count), @"classes": found};
}

#pragma mark - read_file

+ (id)readFile:(NSString *)filename keyword:(NSString *)keyword {
    if (filename.length == 0) return @{@"error": @"required"};
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *paths = @[
        [docs stringByAppendingPathComponent:filename],
        [docs stringByAppendingPathComponent:@"IL2CPP_Dump"],
        [@"/var/mobile/Documents" stringByAppendingPathComponent:filename],
        filename,
    ];
    NSString *content = nil;
    NSString *foundPath = nil;
    for (NSString *p in paths) {
        NSString *full = [p hasSuffix:filename] ? p : [p stringByAppendingPathComponent:filename];
        if ([[NSFileManager defaultManager] fileExistsAtPath:full]) {
            content = [NSString stringWithContentsOfFile:full encoding:NSUTF8StringEncoding error:nil];
            foundPath = full;
            break;
        }
    }
    if (!content) return @{@"error": @"File not found", @"paths_tried": paths};
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    if (keyword.length == 0) {
        return @{@"path": foundPath ?: @"",
                 @"total_lines": @(lines.count),
                 @"preview": [lines subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)lines.count, (NSUInteger)20))]};
    }

    NSString *kwLower = keyword.lowercaseString;
    NSMutableArray *matches = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)lines.count && matches.count < 30; i++) {
        NSString *line = (NSString *)lines[i];
        if ([line.lowercaseString containsString:kwLower]) {
            [matches addObject:@{
                @"line": @(i + 1),
                @"text": [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
            }];
        }
    }
    return @{@"path": foundPath ?: @"",
             @"count": @(matches.count),
             @"matches": matches};
}

@end
