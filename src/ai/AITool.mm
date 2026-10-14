#import "AITool.h"
#import "IL2CPPResolver.h"

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
    [self registerTool:[AITool toolWithName:@"search_classes"
        description:@"Tim class runtime" parameters:@{@"type": @"object", @"properties": @{
            @"keyword": @{@"type": @"string"}}, @"required": @[@"keyword"]}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool searchClasses:args[@"keyword"] ?: @""];
            }];
        }]];

    [self registerTool:[AITool toolWithName:@"search_methods"
        description:@"Tim method runtime" parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"}, @"method_keyword": @{@"type": @"string"}},
            @"required": @[@"class_name"]}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool searchMethods:args[@"class_name"] ?: @"" keyword:args[@"method_keyword"] ?: @""];
            }];
        }]];

    [self registerTool:[AITool toolWithName:@"get_method_rva"
        description:@"Lay RVA method" parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"}, @"method_name": @{@"type": @"string"}},
            @"required": @[@"class_name", @"method_name"]}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool getMethodRVA:args[@"class_name"] ?: @"" method:args[@"method_name"] ?: @""];
            }];
        }]];

    [self registerTool:[AITool toolWithName:@"find_hack_methods"
        description:@"Tim ham hack" parameters:@{@"type": @"object", @"properties": @{
            @"hack_type": @{@"type": @"string"}}, @"required": @[@"hack_type"]}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool findHack:args[@"hack_type"] ?: @""];
            }];
        }]];

    [self registerTool:[AITool toolWithName:@"dump_class_runtime"
        description:@"Dump class runtime" parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"}}, @"required": @[@"class_name"]}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool dumpClassRuntime:args[@"class_name"] ?: @""];
            }];
        }]];

    [self registerTool:[AITool toolWithName:@"find_in_class"
        description:@"Tim field/method trong class" parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"}, @"keyword": @{@"type": @"string"}},
            @"required": @[@"class_name"]}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool findInClass:args[@"class_name"] ?: @"" keyword:args[@"keyword"] ?: @""];
            }];
        }]];

    [self registerTool:[AITool toolWithName:@"read_file"
        description:@"Grep keyword file" parameters:@{@"type": @"object", @"properties": @{
            @"filename": @{@"type": @"string"}, @"keyword": @{@"type": @"string"}},
            @"required": @[@"filename"]}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool readFile:args[@"filename"] ?: @"" keyword:args[@"keyword"] ?: @""];
            }];
        }]];

    [self registerTool:[AITool toolWithName:@"list_files"
        description:@"Liet ke file" parameters:@{@"type": @"object", @"properties": @{}}
        handler:^id(NSDictionary *args) {
            return [AITool runWithTimeout:^{
                return [AITool listFiles];
            }];
        }]];
}

#pragma mark - Timeout wrapper

+ (id)runWithTimeout:(id (^)(void))block {
    __block id result = nil;
    __block BOOL done = NO;

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            result = block();
        } @catch (NSException *e) {
            result = @{@"error": e.reason ?: @"Exception"};
        }
        done = YES;
        dispatch_semaphore_signal(sema);
    });

    // Timeout 5 giây
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
    long waitResult = dispatch_semaphore_wait(sema, timeout);

    if (waitResult != 0 || !done) {
        return @{@"error": @"Timeout - game qua lon, thu lai sau"};
    }

    return result ?: @{@"error": @"No result"};
}

#pragma mark - Class helper

+ (Il2CppClass *)findClass:(NSString *)className {
    if (className.length == 0) return NULL;
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return NULL;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return NULL;

    NSString *lower = className.lowercaseString;
    for (int a = 0; a < domain->assembly_count; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        void *imgPtr = *(void **)asm_;
        if (!imgPtr) continue;
        Il2CppImage *image = (Il2CppImage *)imgPtr;
        if (!image || !image->name) continue;

        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *klass = [r image_get_class:image index:i];
            if (!klass) continue;
            const char *cname = [r class_get_name:klass];
            if (!cname) continue;
            NSString *name = [NSString stringWithUTF8String:cname];
            if ([name.lowercaseString isEqualToString:lower]) return klass;
        }
    }
    return NULL;
}

#pragma mark - findHack (giảm limit)

+ (id)findHack:(NSString *)hackType {
    if (hackType.length == 0) return @{@"error": @"required"};

    NSDictionary *patterns = @{
        @"map": @[@"map", @"teleport", @"warp", @"position"],
        @"speed": @[@"speed", @"velocity", @"move"],
        @"damage": @[@"damage", @"attack", @"hit"],
        @"health": @[@"health", @"hp", @"life", @"god"],
        @"money": @[@"money", @"gold", @"coin"],
    };
    NSArray *keywords = patterns[hackType.lowercaseString] ?: @[hackType];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    NSMutableArray *found = [NSMutableArray array];

    @try {
        // Chỉ 3 assembly đầu, tối đa 5 kết quả
        for (int a = 0; a < domain->assembly_count && a < 3 && found.count < 5; a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            void *imgPtr = *(void **)asm_;
            if (!imgPtr) continue;
            Il2CppImage *image = (Il2CppImage *)imgPtr;
            if (!image || !image->name) continue;

            size_t count = [r image_get_class_count:image];
            // Chỉ 2000 class đầu
            size_t maxClasses = MIN(count, (size_t)2000);

            for (size_t i = 0; i < maxClasses && found.count < 5; i++) {
                Il2CppClass *klass = [r image_get_class:image index:i];
                if (!klass) continue;
                const char *cname = [r class_get_name:klass];
                if (!cname) continue;
                NSString *className = [NSString stringWithUTF8String:cname];

                uint16_t mCount = 0;
                const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
                if (!mList) continue;

                for (uint16_t j = 0; j < mCount && found.count < 5; j++) {
                    const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
                    if (!mn) continue;
                    NSString *mName = [NSString stringWithUTF8String:mn];
                    NSString *mLower = mName.lowercaseString;
                    for (NSString *kw in keywords) {
                        if ([mLower containsString:kw.lowercaseString]) {
                            void *ptr = [r method_get_pointer:(MethodInfo *)mList[j]];
                            uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                            [found addObject:@{@"class": className, @"method": mName,
                                                @"rva": [NSString stringWithFormat:@"0x%llX", rva]}];
                            break;
                        }
                    }
                }
                if (mList) free(mList);
            }
        }
    } @catch (NSException *e) { return @{@"error": e.reason}; }

    if (found.count == 0) {
        return @{@"count": @0, @"methods": @[], @"note": @"Khong tim thay - thu 'search_classes' truoc"};
    }

    return @{@"count": @(found.count), @"methods": found};
}

#pragma mark - Other tools

+ (id)searchClasses:(NSString *)keyword {
    if (keyword.length == 0) return @{@"error": @"keyword required"};
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    NSString *lower = keyword.lowercaseString;
    NSMutableArray *results = [NSMutableArray array];

    @try {
        for (int a = 0; a < domain->assembly_count && results.count < 10; a++) {
            if (a > 3) break;
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            void *imgPtr = *(void **)asm_;
            if (!imgPtr) continue;
            Il2CppImage *image = (Il2CppImage *)imgPtr;
            if (!image || !image->name) continue;

            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count && results.count < 10; i++) {
                Il2CppClass *klass = [r image_get_class:image index:i];
                if (!klass) continue;
                const char *cname = [r class_get_name:klass];
                const char *cns = [r class_get_namespace:klass];
                if (!cname) continue;
                NSString *name = [NSString stringWithUTF8String:cname];
                NSString *ns = cns ? [NSString stringWithUTF8String:cns] : @"";
                if ([name.lowercaseString containsString:lower] ||
                    [ns.lowercaseString containsString:lower]) {
                    [results addObject:@{@"name": name, @"namespace": ns}];
                }
            }
        }
    } @catch (NSException *e) { return @{@"error": e.reason}; }
    return @{@"count": @(results.count), @"classes": results};
}

+ (id)searchMethods:(NSString *)className keyword:(NSString *)keyword {
    if (className.length == 0) return @{@"error": @"class_name required"};
    IL2CPPResolver *r = [ IL2CPPResolver shared];
    if (!0[r resolve]) return @{@"error":;
 @"IL2CPP not    resolved"};

    Il const2CppClass *klass Method = [self findClass:className];
    if (!klass) return @{@"error": @"Class not found"};

    NSString *kwLower = keyword.lowercaseString;
    NSMutableArray *methods = [NSMutableArray array];

    uint16_t mCount = 0;
    const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
    for (uint16_t j = 0; j < mCount && methods.count < 20; j++) {
        const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
        if (!mn) continue;
        NSString *mName = [NSString stringWithUTF8String:mn];
        if (kwLower.length > 0 && ![mName.lowercaseString containsString:kwLower]) continue;
        void *ptr = [r method_get_pointer:(MethodInfo *)mList[j]];
        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
        [methods addObject:@{@"name": mName, @"rva": [NSString stringWithFormat:@"0x%llX", rva]}];
    }
    if (mList) free(mList);

    return @{@"class": className, @"count": @(methods.count), @"methods": methods};
}

+ (id)getMethodRVA:(NSString *)className method:(NSString *)methodName {
    if (className.length == 0 || methodName.length == 0) return @{@"error": @"required"};
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};

    Il2CppClass *klass = [self findClass:className];
    if (!klass) return @{@"error": @"Class not found"};

    uint16_t mCount = 0;
    const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
    for (uint16_t j = 0; j < mCount; j++) {
        const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
        if (!mn) continue;
        NSString *mName = [NSString stringWithUTF8String:mn];
        if (![mName isEqualToString:methodName]) continue;
        void *ptr = [r method_get_pointer:(MethodInfo *)mList[j]];
        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
        if (mList) free(mList);
        return @{@"class": className, @"method": mName, @"rva": [NSString stringWithFormat:@"0x%llX", rva]};
    }
    if (mList) free(mList);
    return @{@"error": @"Method not found"};
}

+ (id)dumpClassRuntime:(NSString *)className {
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};

    Il2CppClass *klass = [self findClass:className];
    if (!klass) return @{@"error": @"Class not found"};

    const char *cns = [r class_get_namespace:klass];
    Il2CppClass *parent = [r class_get_parent:klass];
    NSString *parentName = parent ? [NSString stringWithUTF8String:parent->name] : @"";

    NSMutableArray *fields = [NSMutableArray array];
    uint16_t fCount = 0;
    const FieldInfo **fList = [r class_get_fields:klass count:&fCount];
    for (uint16_t j = 0; j < fCount && fields.count < 50; j++) {
        const char *fn = [r field_get_name:(FieldInfo *)fList[j]];
        int32_t off = [r field_get_offset:(FieldInfo *)fList[j]];
        if (fn) [fields addObject:@{@"name": [NSString stringWithUTF8String:fn],
                                     @"offset": [NSString stringWithFormat:@"0x%X", off]}];
    }
    if (fList) free(fList);

    NSMutableArray *methods = [NSMutableArray array];
    uint16_t mCount =Info **mList = [r class_get_methods:klass count:&mCount];
    for (uint16_t j = 0; j < mCount && methods.count < 50; j++) {
        const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
        void *ptr = [r method_get_pointer:(MethodInfo *)mList[j]];
        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
        if (mn) [methods addObject:@{@"name": [NSString stringWithUTF8String:mn],
                                      @"rva": [NSString stringWithFormat:@"0x%llX", rva]}];
    }
    if (mList) free(mList);

    return @{@"class": className,
             @"namespace": cns ? [NSString stringWithUTF8String:cns] : @"",
             @"parent": parentName,
             @"field_count": @(fields.count),
             @"method_count": @(methods.count),
             @"fields": fields,
             @"methods": methods};
}

+ (id)findInClass:(NSString *)className keyword:(NSString *)keyword {
    NSDictionary *dump = [self dumpClassRuntime:className];
    if (dump[@"error"]) return dump;

    NSString *kwLower = keyword.lowercaseString;
    NSMutableArray *results = [NSMutableArray array];

    for (NSDictionary *f in dump[@"fields"]) {
        if (kwLower.length == 0 || [[f[@"name"] lowercaseString] containsString:kwLower]) {
            [results addObject:@{@"type": @"field", @"name": f[@"name"], @"offset": f[@"offset"]}];
        }
    }
    for (NSDictionary *m in dump[@"methods"]) {
        if (kwLower.length == 0 || [[m[@"name"] lowercaseString] containsString:kwLower]) {
            [results addObject:@{@"type": @"method", @"name": m[@"name"], @"rva": m[@"rva"]}];
        }
    }

    return @{@"class": className, @"keyword": keyword,
             @"count": @(results.count), @"results": results};
}

+ (id)readFile:(NSString *)filename keyword:(NSString *)keyword {
    if (filename.length == 0) return @{@"error": @"required"};
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *paths = @[
        [docs stringByAppendingPathComponent:filename],
        [@"/var/mobile/Documents" stringByAppendingPathComponent:filename],
        filename,
    ];
    NSString *content = nil;
    for (NSString *p in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            content = [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil];
            break;
        }
    }
    if (!content) return @{@"error": @"File not found"};
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    if (keyword.length == 0) return @{@"total_lines": @(lines.count)};

    NSString *kwLower = keyword.lowercaseString;
    NSMutableArray *matches = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)lines.count && matches.count < 20; i++) {
        NSString *line = (NSString *)lines[i];
        if ([line.lowercaseString containsString:kwLower]) {
            [matches addObject:@{@"line": @(i + 1),
                                 @"text": [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]}];
        }
    }
    return @{@"count": @(matches.count), @"matches": matches};
}

+ (id)listFiles {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *paths = @[docs, @"/var/mobile/Documents"];
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *dir in paths) {
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *f in contents) [files addObject:f];
    }
    return @{@"count": @(files.count), @"files": files};
}

@end
