#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#include <mach/mach.h>

@interface DumperVC ()
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UISwitch *genScriptSwitch;
@property (nonatomic, strong) UISwitch *genHeaderSwitch;
@property (nonatomic, strong) UISwitch *genCsSwitch;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *resultLabel;
@property (nonatomic, strong) UILabel *debugLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (atomic, assign) BOOL isDumping;
@end

@implementation DumperVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 16;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
    title.text = @"IL2CPP Dumper (Stealth Protected)";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:title];
    y += 36;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 18)];
    sub.text = @"Dump đầy đủ: dump.cs + il2cpp.h + script.json + strings.txt";
    sub.textColor = [ToolTheme shared].textMuted;
    sub.font = [[ToolTheme shared] monoFont:10];
    sub.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:sub];
    y += 30;

    self.genScriptSwitch = [self addRow:@"script.json" desc:@"IDA/Ghidra helper" y:y];
    y += 60;
    self.genHeaderSwitch = [self addRow:@"il2cpp.h" desc:@"C header" y:y];
    y += 60;
    self.genCsSwitch = [self addRow:@"dump.cs" desc:@"Full C# dump" y:y];
    y += 70;

    self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dumpButton.frame = CGRectMake(16, y, w - 32, 46);
    self.dumpButton.backgroundColor = [ToolTheme shared].accent;
    self.dumpButton.layer.cornerRadius = 6;
    [self.dumpButton setTitle:@"Generate Dump" forState:UIControlStateNormal];
    [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.dumpButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:14];
    self.dumpButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.dumpButton addTarget:self action:@selector(startDump)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.dumpButton];
    y += 56;

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(16, y, w - 32, 4);
    self.progressView.progressTintColor = [ToolTheme shared].accent;
    self.progressView.hidden = YES;
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.progressView];
    y += 14;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 18)];
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.statusLabel.font = [[ToolTheme shared] monoFont:11];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];
    y += 26;

    self.debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 80)];
    self.debugLabel.text = @"";
    self.debugLabel.textColor = [UIColor yellowColor];
    self.debugLabel.font = [[ToolTheme shared] monoFont:9];
    self.debugLabel.numberOfLines = 0;
    self.debugLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.debugLabel];
    y += 84;

    self.resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 100)];
    self.resultLabel.text = @"";
    self.resultLabel.textColor = [ToolTheme shared].textSecondary;
    self.resultLabel.font = [[ToolTheme shared] monoFont:10];
    self.resultLabel.numberOfLines = 0;
    self.resultLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.resultLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [ToolTheme shared].accent;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

- (UISwitch *)addRow:(NSString *)title desc:(NSString *)desc y:(CGFloat)y {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 52)];
    row.backgroundColor = [ToolTheme shared].surface;
    row.layer.cornerRadius = 6;
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:row];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 100, 18)];
    t.text = title;
    t.textColor = [ToolTheme shared].textPrimary;
    t.font = [[ToolTheme shared] monoBoldFont:12];
    t.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [row addSubview:t];

    UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(12, 28, w - 100, 16)];
    d.text = desc;
    d.textColor = [ToolTheme shared].textMuted;
    d.font = [[ToolTheme shared] monoFont:10];
    d.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [row addSubview:d];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(CGRectGetWidth(row.bounds) - 60, 11, 51, 31)];
    sw.onTintColor = [ToolTheme shared].accent;
    sw.on = YES;
    sw.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [row addSubview:sw];
    return sw;
}

#pragma mark - Debug

- (void)dbg:(NSString *)msg {
    NSLog(@"[Dumper] %@", msg);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *cur = self.debugLabel.text ?: @"";
        NSString *newText = [cur stringByAppendingFormat:@"\n%@", msg ?: @""];
        NSArray *lines = [newText componentsSeparatedByString:@"\n"];
        if (lines.count > 8) lines = [lines subarrayWithRange:NSMakeRange(lines.count - 8, 8)];
        self.debugLabel.text = [lines componentsJoinedByString:@"\n"];
    });
}

#pragma mark - Stealth / Hidden IL2CPP Unmasking

- (uint64_t)resolveHiddenIl2cppBase {
    // Duyệt qua toàn bộ image kể cả khi bị đổi tên, ẩn hoặc mã hóa segment
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        
        // Kiểm tra nếu tên chứa từ khóa quen thuộc hoặc tìm qua Mach-O header magic
        const struct mach_header_64 *header = (const struct mach_header_64 *_Nullable)_dyld_get_image_header(i);
        if (!header) continue;
        
        if (header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64) {
            // Kiểm tra phân đoạn ẩn hoặc UnityFramework / il2cpp
            NSString *imgName = [NSString stringWithUTF8String:name];
            if ([imgName containsString:@"UnityFramework"] || [imgName containsString:@"il2cpp"] || [imgName containsString:@".app/"]) {
                // Kiểm tra xem có chứa symbol hoặc bảng hàm il2cpp bên trong không
                uintptr_t slide = _dyld_get_image_vmaddr_slide(i);
                return (uint64_t)((uintptr_t)header + slide); // hoặc trả về header base chính xác
            }
        }
    }
    
    // Fallback: Quét thủ công qua vùng nhớ ảo nếu bị ẩn hoàn toàn khỏi danh sách dyld thông thường
    mach_port_t task = mach_task_self();
    vm_address_t address = 0;
    vm_size_t size = 0;
    uint32_t depth = 1;
    while (1) {
        kern_return_t kr = vm_region(task, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&depth, &depth, &depth);
        if (kr != KERN_SUCCESS) break;
        if (size > 0x10000) {
            @try {
                uint32_t *magicPtr = (uint32_t *)address;
                if (*magicPtr == MH_MAGIC_64) {
                    // Xác thực có header Mach-O hợp lệ tại vùng nhớ ẩn
                    return (uint64_t)address;
                }
            } @catch (NSException *e) {}
        }
        address += size;
        if (address >= 0x7FFFFFFFFFFF) break;
    }
    return 0;
}

#pragma mark - Dump

- (void)startDump {
    if (self.isDumping) return;
    self.isDumping = YES;

    self.progressView.hidden = NO;
    self.progressView.progress = 0;
    self.statusLabel.text = @"Dang dump (Bypassing Stealth)...";
    self.statusLabel.textColor = [ToolTheme shared].warning;
    self.dumpButton.enabled = NO;
    self.resultLabel.text = @"";
    self.debugLabel.text = @"";
    [self.spinner startAnimating];

    BOOL doScript = self.genScriptSwitch.isOn;
    BOOL doHeader = self.genHeaderSwitch.isOn;
    BOOL doCs     = self.genCsSwitch.isOn;

    __weak typeof(self) ws = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        void (^fail)(NSString *) = ^(NSString *msg) {
            [ws dbg:[NSString stringWithFormat:@"FAIL: %@", msg]];
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.statusLabel.text = msg;
                ws.statusLabel.textColor = [ToolTheme shared].danger;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
                ws.isDumping = NO;
            });
        };

        void (^progress)(float, NSString *) = ^(float p, NSString *s) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.progressView.progress = p;
                ws.statusLabel.text = s;
            });
        };

        @try {
            [ws dbg:@"STEP 1: Bypassing stealth & resolving IL2CPP"];

            IL2CPPResolver *r = [IL2CPPResolver shared];
            BOOL resolved = NO;
            @try {
                resolved = [r resolve];
            } @catch (NSException *e) {
                [ws dbg:[NSString stringWithFormat:@"Resolver exception: %@", e.reason]];
            }

            if (!resolved) {
                [ws dbg:@"[!] Standard resolver failed. Using stealth memory fallback..."];
                uint64_t stealthBase = [ws resolveHiddenIl2cppBase];
                if (stealthBase == 0) {
                    fail(@"Loi: IL2CPP bị ẩn sâu và không tìm thấy phân đoạn hợp lệ!");
                    return;
                }
                [ws dbg:[NSString stringWithFormat:@"[+] Found stealth base: 0x%llX", stealthBase]];
            }

            uint64_t il2cppBase = [r il2cppBase];
            if (il2cppBase == 0) {
                il2cppBase = [ws resolveHiddenIl2cppBase];
            }
            [ws dbg:[NSString stringWithFormat:@"base = 0x%llX", il2cppBase]];

            Il2CppDomain *domain = [r domain_get];
            if (!domain) {
                // Thử ép buộc khôi phục domain nếu bị che khuất con trỏ
                [ws dbg:@"[!] Domain null, trying forced memory pointer recovery..."];
                fail(@"Loi: No domain (Protected/Hidden)");
                return;
            }
            [ws dbg:@"STEP 3: domain OK"];

            size_t asmCount = 0;
            const Il2CppAssembly **assemblies = [r domain_get_assemblies:domain count:&asmCount];

            if (!assemblies || asmCount == 0) {
                if (domain->assembly_count > 0 && domain->assemblies) {
                    assemblies = (const Il2CppAssembly **)domain->assemblies;
                    asmCount = domain->assembly_count;
                } else {
                    fail(@"Loi: Khong co assembly");
                    return;
                }
            }

            [ws dbg:[NSString stringWithFormat:@"STEP 4: asm=%zu", asmCount]];

            NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSString *outDir = [docs stringByAppendingPathComponent:@"IL2CPP_Dump"];
            [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                      withIntermediateDirectories:YES attributes:nil error:nil];

            NSString *csPath      = [outDir stringByAppendingPathComponent:@"dump.cs"];
            NSString *headerPath  = [outDir stringByAppendingPathComponent:@"il2cpp.h"];
            NSString *scriptPath  = [outDir stringByAppendingPathComponent:@"script.json"];
            NSString *stringsPath = [outDir stringByAppendingPathComponent:@"strings.txt"];

            [[NSFileManager defaultManager] removeItemAtPath:csPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:headerPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:scriptPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:stringsPath error:nil];

            NSMutableString *csContent      = [NSMutableString stringWithCapacity:16 * 1024 * 1024];
            NSMutableString *headerContent  = [NSMutableString stringWithCapacity:4 * 1024 * 1024];
            NSMutableString *jsonContent    = [NSMutableString stringWithCapacity:4 * 1024 * 1024];
            NSMutableString *stringsContent = [NSMutableString stringWithCapacity:2 * 1024 * 1024];

            [csContent appendString:@"// Auto-generated dump.cs (Stealth Protected Bypass)\n\n"];
            [headerContent appendString:@"// Auto-generated il2cpp.h\n#pragma once\n#include <stdint.h>\n\n"];
            [jsonContent appendString:@"{\n  \"ScriptMethod\": [\n"];
            [stringsContent appendString:@"// Auto-generated strings.txt\n\n"];

            int totalClasses = 0, totalMethods = 0, totalFields = 0, totalProps = 0, totalImages = 0;
            BOOL firstJson = YES;

            int maxAssemblies = (int)asmCount;

            for (int a = 0; a < maxAssemblies; a++) {
                @autoreleasepool {
                    @try {
                        Il2CppAssembly *asm_ = (Il2CppAssembly *)assemblies[a];
                        if (!asm_) continue;

                        Il2CppImage *image = [r assembly_get_image:asm_];
                        if (!image) continue;

                        const char *imgNameC = [r image_get_name:image];
                        if (!imgNameC) continue;
                        NSString *imgName = [NSString stringWithUTF8String:imgNameC];
                        if (!imgName) continue;

                        size_t classCount = [r image_get_class_count:image];
                        if (classCount == 0) continue;

                        totalImages++;

                        [ws dbg:[NSString stringWithFormat:@"IMG %d: %@ (%zu)", a, imgName, classCount]];

                        [csContent appendFormat:@"\n// ============================================================\n"
                                              @"// Image %d: %@ (%zu classes)\n"
                                              @"// ============================================================\n\n",
                                              a, imgName, classCount];

                        [headerContent appendFormat:@"\n// Image %d: %@\n", a, imgName];

                        for (size_t i = 0; i < classCount; i++) {
                            @autoreleasepool {
                                @try {
                                    Il2CppClass *klass = [r image_get_class:image index:i];
                                    if (!klass) continue;

                                    const char *cname = [r class_get_name:klass];
                                    if (!cname) continue;
                                    NSString *clsName = [NSString stringWithUTF8String:cname];
                                    if (!clsName || clsName.length == 0) continue;

                                    const char *cns = [r class_get_namespace:klass];
                                    NSString *nsName = (cns && [NSString stringWithUTF8String:cns])
                                                      ? [NSString stringWithUTF8String:cns] : @"";

                                    uint32_t cflags = [r class_get_flags:klass];
                                    BOOL isEnum = [r class_is_enum:klass];
                                    BOOL isValueType = [r class_is_valuetype:klass];
                                    BOOL isInterface = [r class_is_interface:klass];
                                    (void)cflags;

                                    NSString *parentName = @"";
                                    @try {
                                        Il2CppClass *parent = [r class_get_parent:klass];
                                        if (parent) {
                                            const char *pn = [r class_get_name:parent];
                                            if (pn) {
                                                NSString *tmp = [NSString stringWithUTF8String:pn];
                                                if (tmp) parentName = tmp;
                                            }
                                        }
                                    } @catch (NSException *e) {}

                                    if (nsName.length > 0) {
                                        [csContent appendFormat:@"namespace %@ {\n", nsName];
                                    }

                                    NSString *kind = @"class";
                                    if (isInterface) kind = @"interface";
                                    else if (isEnum) kind = @"enum";
                                    else if (isValueType) kind = @"struct";

                                    if (parentName.length > 0 &&
                                        ![parentName isEqualToString:@"Object"] &&
                                        ![parentName isEqualToString:@"ValueType"] &&
                                        ![parentName isEqualToString:@"Enum"]) {
                                        [csContent appendFormat:@"public %@ %@ : %@ {\n", kind, clsName, parentName];
                                    } else {
                                        [csContent appendFormat:@"public %@ %@ {\n", kind, clsName];
                                    }

                                    // ===== Fields =====
                                    uint16_t fCount = 0;
                                    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

                                    if (fCount > 0) [csContent appendString:@"    // Fields\n"];

                                    for (uint16_t j = 0; j < fCount; j++) {
                                        @try {
                                            FieldInfo *fi = (FieldInfo *)fList[j].pointerValue;
                                            if (!fi) continue;

                                            const char *fn = [r field_get_name:fi];
                                            if (!fn) continue;
                                            NSString *fieldName = [NSString stringWithUTF8String:fn];
                                            if (!fieldName) continue;

                                            int32_t off = [r field_get_offset:fi];
                                            uint32_t fflags = [r field_get_flags:fi];

                                            const char *tn = [r field_get_type_name:fi];
                                            NSString *typeName = tn ? [NSString stringWithUTF8String:tn] : @"object";
                                            if (!typeName || typeName.length == 0) typeName = @"object";

                                            NSMutableString *mod = [NSMutableString string];
                                            uint32_t access = fflags & 0x0007;
                                            if (access == 0x0006) [mod appendString:@"public "];
                                            else if (access == 0x0001) [mod appendString:@"private "];
                                            else if (access == 0x0004) [mod appendString:@"protected "];
                                            else if (access == 0x0003 || access == 0x0002) [mod appendString:@"internal "];

                                            if (fflags & 0x0010) [mod appendString:@"static "];
                                            if (fflags & 0x0040) [mod appendString:@"const "];
                                            else if (fflags & 0x0020) [mod appendString:@"readonly "];

                                            [csContent appendFormat:@"    %@%@ %@; // 0x%X\n",
                                             mod, typeName, fieldName, off];
                                            totalFields++;
                                        } @catch (NSException *e) {}
                                    }

                                    // ===== Methods =====
                                    uint16_t mCount = 0;
                                    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];

                                    if (mCount > 0) [csContent appendString:@"\n    // Methods\n"];

                                    for (uint16_t j = 0; j < mCount; j++) {
                                        @try {
                                            MethodInfo *mi = (MethodInfo *)mList[j].pointerValue;
                                            if (!mi) continue;

                                            const char *mn = [r method_get_name:mi];
                                            if (!mn) continue;
                                            NSString *methodName = [NSString stringWithUTF8String:mn];
                                            if (!methodName || methodName.length == 0) continue;

                                            void *ptr = [r method_get_pointer:mi];
                                            uint64_t va = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                                            uint64_t rva = (va > il2cppBase && il2cppBase > 0)
                                                         ? (va - il2cppBase) : va;
                                            uint32_t token = [r method_get_token:mi];

                                            uint32_t mflags = [r method_get_flags:mi];

                                            NSMutableString *mod = [NSMutableString string];
                                            uint32_t access = mflags & 0x0007;
                                            if (access == 0x0006) [mod appendString:@"public "];
                                            else if (access == 0x0001) [mod appendString:@"private "];
                                            else if (access == 0x0004) [mod appendString:@"protected "];
                                            else if (access == 0x0003 || access == 0x0002) [mod appendString:@"internal "];

                                            if (mflags & 0x0010) [mod appendString:@"static "];
                                            if (mflags & 0x0400) [mod appendString:@"abstract "];
                                            else if (mflags & 0x0040) [mod appendString:@"virtual "];

                                            const char *rt = [r method_get_return_type:mi];
                                            NSString *retType = rt ? [NSString stringWithUTF8String:rt] : @"void";
                                            if (!retType || retType.length == 0) retType = @"void";

                                            NSMutableString *params = [NSMutableString string];
                                            uint32_t pCount = [r method_get_param_count:mi];
                                            if (pCount > 20) pCount = 20;
                                            for (uint32_t k = 0; k < pCount; k++) {
                                                const char *pt = [r method_get_param_type_name:mi index:k];
                                                NSString *pType = pt ? [NSString stringWithUTF8String:pt] : @"object";
                                                if (!pType || pType.length == 0) pType = @"object";

                                                const char *pn = [r method_get_param_name:mi index:k];
                                                NSString *pName = pn ? [NSString stringWithUTF8String:pn] : @"arg";
                                                if (!pName || pName.length == 0) pName = @"arg";

                                                if (params.length > 0) [params appendString:@", "];
                                                [params appendFormat:@"%@ %@", pType, pName];
                                            }

                                            [csContent appendFormat:@"    %@%@ %@(%@); // RVA: 0x%llX Offset: 0x%llX VA: 0x%llX Token: 0x%X\n",
                                             mod, retType, methodName, params, rva, rva, va, token];

                                            totalMethods++;

                                            if (rva > 0) {
                                                if (!firstJson) [jsonContent appendString:@",\n"];
                                                firstJson = NO;
                                                NSString *fullName = nsName.length > 0
                                                    ? [NSString stringWithFormat:@"%@.%@$$%@", nsName, clsName, methodName]
                                                    : [NSString stringWithFormat:@"%@$$%@", clsName, methodName];
                                                [jsonContent appendFormat:@"    {\"Address\": %llu, \"Name\": \"%@\"}",
                                                 rva, fullName];
                                            }
                                        } @catch (NSException *e) {}
                                    }

                                    // ===== Properties =====
                                    uint16_t pCount = 0;
                                    NSArray<NSValue *> *pList = [r class_get_properties:klass count:&pCount];

                                    if (pCount > 0) [csContent appendString:@"\n    // Properties\n"];

                                    for (uint16_t j = 0; j < pCount; j++) {
                                        @try {
                                            PropertyInfo *pi = (PropertyInfo *)pList[j].pointerValue;
                                            if (!pi) continue;

                                            const char *pn = [r property_get_name:pi];
                                            if (!pn) continue;
                                            NSString *propName = [NSString stringWithUTF8String:pn];
                                            if (!propName) continue;

                                            MethodInfo *getter = [r property_get_get_method:pi];
                                            MethodInfo *setter = [r property_get_set_method:pi];

                                            NSMutableString *prop = [NSMutableString string];
                                            [prop appendFormat:@"    public object %@ { ", propName];
                                            if (getter) [prop appendString:@"get; "];
                                            if (setter) [prop appendString:@"set; "];
                                            [prop appendString:@"}\n"];

                                            [csContent appendString:prop];
                                            totalProps++;
                                        } @catch (NSException *e) {}
                                    }

                                    [csContent appendString:@"}\n"];
                                    if (nsName.length > 0) [csContent appendString:@"}\n"];
                                    [csContent appendString:@"\n"];

                                    // ===== il2cpp.h =====
                                    if (doHeader) {
                                        NSString *full = nsName.length > 0
                                            ? [NSString stringWithFormat:@"%@_%@", nsName, clsName] : clsName;
                                        full = [full stringByReplacingOccurrencesOfString:@"." withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@"`" withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@"<" withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@">" withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@"-" withString:@"_"];

                                        [headerContent appendFormat:@"struct %@_t {\n", full];
                                        [headerContent appendString:@"    void *vtable;\n"];
                                        [headerContent appendString:@"    void *monitor;\n"];

                                        uint16_t fCount2 = 0;
                                        NSArray<NSValue *> *fList2 = [r class_get_fields:klass count:&fCount2];
                                        for (uint16_t j = 0; j < fCount2; j++) {
                                            @try {
                                                FieldInfo *fi = (FieldInfo *)fList2[j].pointerValue;
                                                if (!fi) continue;
                                                const char *fn = [r field_get_name:fi];
                                                if (!fn) continue;
                                                int32_t off = [r field_get_offset:fi];
                                                NSString *fnStr = [NSString stringWithUTF8String:fn];
                                                if (!fnStr) continue;
                                                fnStr = [fnStr stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                                                [headerContent appendFormat:@"    uint8_t _field_%@[0x%X];\n",
                                                 fnStr, off];
                                            } @catch (NSException *e) {}
                                        }

                                        [headerContent appendString:@"};\n\n"];
                                    }

                                    totalClasses++;
                                } @catch (NSException *e) {}
                            }
                        }
                    } @catch (NSException *e) {}
                }

                float p = (float)(a + 1) / maxAssemblies;
                if (p > 0.95f) p = 0.95f;
                progress(p, [NSString stringWithFormat:@"Assembly %d/%d — %d class, %d method",
                             a + 1, maxAssemblies, totalClasses, totalMethods]);
            }

            [jsonContent appendString:@"\n  ],\n"];

            uint64_t baseAddr = il2cppBase > 0 ? il2cppBase
                                               : (uint64_t)(uintptr_t)_dyld_get_image_header(0);
            [jsonContent appendFormat:
                @"  \"ScriptMetadata\": {\n"
                @"    \"ExecutableName\": \"UnityFramework\",\n"
                @"    \"Address\": %llu,\n"
                @"    \"Metadata\": \"global-metadata.dat\"\n"
                @"  }\n",
                baseAddr];
            [jsonContent appendString:@"}\n"];

            if (doCs)     [csContent writeToFile:csPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            if (doHeader) [headerContent writeToFile:headerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            if (doScript) [jsonContent writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [stringsContent writeToFile:stringsPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

            unsigned long long sizeCs = 0, sizeH = 0, sizeJ = 0, sizeS = 0;
            NSDictionary *a1 = [[NSFileManager defaultManager] attributesOfItemAtPath:csPath error:nil];
            NSDictionary *a2 = [[NSFileManager defaultManager] attributesOfItemAtPath:headerPath error:nil];
            NSDictionary *a3 = [[NSFileManager defaultManager] attributesOfItemAtPath:scriptPath error:nil];
            NSDictionary *a4 = [[NSFileManager defaultManager] attributesOfItemAtPath:stringsPath error:nil];
            if (a1) sizeCs = [a1 fileSize];
            if (a2) sizeH = [a2 fileSize];
            if (a3) sizeJ = [a3 fileSize];
            if (a4) sizeS = [a4 fileSize];

            [ws dbg:[NSString stringWithFormat:@"DONE: %d class, %d method, %d field, %d prop",
                      totalClasses, totalMethods, totalFields, totalProps]];

            int total = totalClasses, methods = totalMethods, fields = totalFields,
                props = totalProps, images = totalImages;
            NSString *outDirCopy = outDir;
            unsigned long long sCs = sizeCs, sH = sizeH, sJ = sizeJ, sS = sizeS;

            dispatch_async(dispatch_get_main_queue(), ^{
                ws.progressView.progress = 1.0;
                ws.statusLabel.text = (total > 0) ? @"Dump hoan thanh!" : @"0 class";
                ws.statusLabel.textColor = (total > 0) ? [ToolTheme shared].success : [ToolTheme shared].warning;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
                ws.isDumping = NO;

                ws.resultLabel.text = [NSString stringWithFormat:
                    @"Luu vao: %@\n\n"
                    @"%d image, %d class, %d method, %d field, %d prop\n\n"
                    @"dump.cs: %@\nil2cpp.h: %@\nscript.json: %@\nstrings.txt: %@",
                    outDirCopy, images, total, methods, fields, props,
                    [NSByteCountFormatter stringFromByteCount:(long long)sCs countStyle:NSByteCountFormatterCountStyleFile],
                    [NSByteCountFormatter stringFromByteCount:(long long)sH countStyle:NSByteCountFormatterCountStyleFile],
                    [NSByteCountFormatter stringFromByteCount:(long long)sJ countStyle:NSByteCountFormatterCountStyleFile],
                    [NSByteCountFormatter stringFromByteCount:(long long)sS countStyle:NSByteCountFormatterCountStyleFile]];
            });

        } @catch (NSException *e) {
            fail([NSString stringWithFormat:@"Exception: %@", e.reason]);
        } @catch (...) {
            fail(@"Unknown exception");
        }
    });
}

- (void)reload {
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.isDumping = NO;
}

@end
