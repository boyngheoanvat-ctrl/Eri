#import "AITool.h"
#import "IL2CPPResolver.h"
#import "AIMethodAnalyzer.h"

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
    [self registerTool:[AITool toolWithName:@"find_hack_methods"
        description:@"Tim ham hack — CHI 1 LAN"
        parameters:@{@"type": @"object", @"properties": @{
            @"hack_type": @{@"type": @"string"}}, @"required": @[@"hack_type"]}
        handler:^id(NSDictionary *args) {
            return [AITool findHack:args[@"hack_type"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"search_classes"
        description:@"Tim class runtime"
        parameters:@{@"type": @"object", @"properties": @{
            @"keyword": @{@"type": @"string"}}, @"required": @[@"keyword"]}
        handler:^id(NSDictionary *args) {
            return [AITool searchClasses:args[@"keyword"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"dump_class_runtime"
        description:@"Dump class runtime"
        parameters:@{@"type": @"object", @"properties": @{
            @"class_name": @{@"type": @"string"}}, @"required": @[@"class_name"]}
        handler:^id(NSDictionary *args) {
            return [AITool dumpClassRuntime:args[@"class_name"] ?: @""];
        }]];

    [self registerTool:[AITool toolWithName:@"read_file"
        description:@"Grep file"
        parameters:@{@"type": @"object", @"properties": @{
            @"filename": @{@"type": @"string"},
            @"keyword": @{@"type": @"string"}}, @"required": @[@"filename"]}
        handler:^id(NSDictionary *args) {
            return [AITool readFile:args[@"filename"] ?: @"" keyword:args[@"keyword"] ?: @""];
        }]];
}

- (NSDictionary *)openAISchema {
    return @{@"type": @"function", @"function": @{
        @"name": self.name ?: @"", @"description": self.toolDescription ?: @"",
        @"parameters": self.parameters ?: @{@"type": @"object", @"properties": @{}}}};
}

#pragma mark - findHack

+ (id)findHack:(NSString *)hackType {
    if (hackType.length == 0) return @{@"error": @"required"};

    NSDictionary *patterns = @{
        @"map":     @[@"map", @"teleport", @"warp", @"moveto", @"setpos"],
        @"speed":   @[@"speed", @"velocity", @"move"],
        @"damage":  @[@"damage", @"attack", @"hit"],
        @"health":  @[@"health", @"hp", @"life", @"god"],
        @"money":   @[@"money", @"gold", @"coin"],
    };
    NSArray *keywords = patterns[hackType.lowercaseString] ?: @[hackType];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    NSMutableArray *found = [NSMutableArray array];

    @try {
        if (domain->assembly_count > 0) {
            Il2CppAssembly *asm_ = domain->assemblies[0];
            if (asm_) {
                Il2CppImage *image = [r assembly_get_image:asm_];
                if (image) {
                    const char *imgNameC = [r image_get_name:image];
                    if (imgNameC) {
                        size_t count = [r image_get_class_count:image];
                        size_t maxClasses = MIN(count, (size_t)300);

                        for (size_t i = 0; i < maxClasses && found.count < 3; i++) {
                            Il2CppClass *klass = [r image_get_class:image index:i];
                            if (!klass) continue;
                            const char *cname = [r class_get_name:klass];
                            if (!cname) continue;
                            NSString *className = [NSString stringWithUTF8String:cname];
                            if (!className) continue;

                            uint16_t mCount = 0;
                            NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];

                            for (uint16_t j = 0; j < mCount && found.count < 3; j++) {
                                MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                                if (!m) continue;
                                const char *mn = [r method_get_name:m];
                                if (!mn) continue;
                                NSString *mName = [NSString stringWithUTF8String:mn];
                                if (!mName) continue;
                                NSString *mLower = mName.lowercaseString;

                                for (NSString *kw in keywords) {
                                    if ([mLower containsString:kw.lowercaseString]) {
                                        void *ptr = [r method_get_pointer:m];
                                        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                                        [found addObject:@{
                                            @"class": className,
                                            @"method": mName,
                                            @"rva": [NSString stringWithFormat:@"0x%llX", rva]
                                        }];
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {
        return @{@"error": e.reason ?: @"Exception"};
    }

    return @{@"count": @(found.count), @"methods": found};
}

+ (id)searchClasses:(NSString *)keyword {
    if (keyword.length == 0) return @{@"error": @"required"};
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

            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            const char *imgNameC = [r image_get_name:image];
            if (!imgNameC) continue;

            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count && results.count < 10; i++) {
                Il2CppClass *klass = [r image_get_class:image index:i];
                if (!klass) continue;
                const char *cname = [r class_get_name:klass];
                const char *cns = [r class_get_namespace:klass];
                if (!cname) continue;
                NSString *name = [NSString stringWithUTF8String:cname];
                if (!name) continue;
                NSString *ns = (cns && [NSString stringWithUTF8String:cns])
                              ? [NSString stringWithUTF8String:cns] : @"";
                if ([name.lowercaseString containsString:lower] ||
                    [ns.lowercaseString containsString:lower]) {
                    [results addObject:@{@"name": name, @"namespace": ns ?: @""}];
                }
            }
        }
    } @catch (NSException *e) { return @{@"error": e.reason ?: @"Exception"}; }
    return @{@"count": @(results.count), @"classes": results};
}

+ (id)dumpClassRuntime:(NSString *)className {
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @{@"error": @"No domain"};

    NSString *lower = className.lowercaseString;
    Il2CppClass *klass = NULL;

    for (int a = 0; a < domain->assembly_count && !klass; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;

        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image) continue;

        const char *imgNameC = [r image_get_name:image];
        if (!imgNameC) continue;

        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k) continue;
            const char *cname = [r class_get_name:k];
            if (!cname) continue;
            NSString *n = [NSString stringWithUTF8String:cname];
            if (!n) continue;
            if ([n.lowercaseString isEqualToString:lower]) { klass = k; break; }
        }
    }
    if (!klass) return @{@"error": @"Class not found"};

    NSMutableArray *fields = [NSMutableArray array];
    uint16_t fCount = 0;
    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];
    for (uint16_t j = 0; j < fCount && fields.count < 50; j++) {
        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
        if (!f) continue;
        const char *fn = [r field_get_name:f];
        int32_t off = [r field_get_offset:f];
        if (fn) {
            [fields addObject:@{
                @"name": [NSString stringWithUTF8String:fn],
                @"offset": [NSString stringWithFormat:@"0x%X", off]
            }];
        }
    }

    NSMutableArray *methods = [NSMutableArray array];
    uint16_t mCount = 0;
    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
    for (uint16_t j = 0; j < mCount && methods.count < 50; j++) {
        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
        if (!m) continue;
        const char *mn = [r method_get_name:m];
        void *ptr = [r method_get_pointer:m];
        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
        if (mn) {
            [methods addObject:@{
                @"name": [NSString stringWithUTF8String:mn],
                @"rva": [NSString stringWithFormat:@"0x%llX", rva]
            }];
        }
    }

    return @{@"class": className,
             @"field_count": @(fields.count),
             @"method_count": @(methods.count),
             @"fields": fields,
             @"methods": methods};
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
            [matches addObject:@{
                @"line": @(i + 1),
                @"text": [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
            }];
        }
    }
    return @{@"count": @(matches.count), @"matches": matches};
}

@end
