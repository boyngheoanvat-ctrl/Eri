#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"
#import <mach-o/dyld.h>

@interface DumperVC ()
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *resultLabel;
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
    title.text = @"IL2CPP Dumper";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    [self.view addSubview:title];
    y += 36;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 18)];
    sub.text = @"Dump GameAssembly.dll (code game)";
    sub.textColor = [ToolTheme shared].textMuted;
    sub.font = [[ToolTheme shared] monoFont:10];
    [self.view addSubview:sub];
    y += 40;

    self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dumpButton.frame = CGRectMake(16, y, w - 32, 50);
    self.dumpButton.backgroundColor = [ToolTheme shared].accent;
    self.dumpButton.layer.cornerRadius = 6;
    [self.dumpButton setTitle:@"Generate Dump" forState:UIControlStateNormal];
    [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.dumpButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:14];
    [self.dumpButton addTarget:self action:@selector(startDump)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.dumpButton];
    y += 66;

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(16, y, w - 32, 4);
    self.progressView.progressTintColor = [ToolTheme shared].accent;
    self.progressView.hidden = YES;
    [self.view addSubview:self.progressView];
    y += 14;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 18)];
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.statusLabel.font = [[ToolTheme shared] monoFont:11];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    y += 26;

    self.resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 200)];
    self.resultLabel.text = @"";
    self.resultLabel.textColor = [ToolTheme shared].textSecondary;
    self.resultLabel.font = [[ToolTheme shared] monoFont:10];
    self.resultLabel.numberOfLines = 0;
    [self.view addSubview:self.resultLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [ToolTheme shared].accent;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

#pragma mark - Dump

- (void)startDump {
    if (self.isDumping) return;
    self.isDumping = YES;

    self.progressView.hidden = NO;
    self.progressView.progress = 0;
    self.statusLabel.text = @"Dang dump...";
    self.statusLabel.textColor = [ToolTheme shared].warning;
    self.dumpButton.enabled = NO;
    self.resultLabel.text = @"";
    [self.spinner startAnimating];

    __weak typeof(self) ws = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        void (^fail)(NSString *) = ^(NSString *msg) {
            NSLog(@"[Dumper] FAIL: %@", msg);
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
            NSLog(@"[Dumper] START");

            IL2CPPResolver *r = [IL2CPPResolver shared];
            if (!r || ![r resolve]) { fail(@"Loi: IL2CPP not resolved"); return; }

            Il2CppDomain *domain = [r domain_get];
            if (!domain) { fail(@"Loi: No domain"); return; }

            if (domain->assembly_count <= 0 || domain->assemblies == NULL) {
                fail(@"Loi: assembly_count = 0");
                return;
            }

            // ===== Tìm GameAssembly.dll =====
            Il2CppImage *targetImage = NULL;
            int targetIdx = -1;

            int maxAssemblies = (int)domain->assembly_count;
            for (int a = 0; a < maxAssemblies; a++) {
                Il2CppAssembly *asm_ = domain->assemblies[a];
                if (!asm_ || (uintptr_t)asm_ < 0x1000) continue;

                Il2CppImage *image = [r assembly_get_image:asm_];
                if (!image || (uintptr_t)image < 0x1000) continue;

                const char *nameC = [r image_get_name:image];
                if (!nameC) continue;
                NSString *name = [NSString stringWithUTF8String:nameC];
                if (!name) continue;

                if ([name isEqualToString:@"GameAssembly.dll"]) {
                    targetImage = image;
                    targetIdx = a;
                    NSLog(@"[Dumper] Found GameAssembly.dll at index %d", a);
                    break;
                }
            }

            if (!targetImage) {
                fail(@"Khong tim thay GameAssembly.dll");
                return;
            }

            progress(0.05f, @"Dang doc GameAssembly.dll...");

            size_t classCount = [r image_get_class_count:targetImage];
            if (classCount == 0) {
                fail(@"GameAssembly.dll 0 class");
                return;
            }

            NSLog(@"[Dumper] GameAssembly.dll: %zu classes", classCount);

            // ===== Bộ đệm =====
            NSMutableString *csContent   = [NSMutableString stringWithCapacity:1024 * 1024];
            NSMutableString *jsonContent = [NSMutableString stringWithCapacity:512 * 1024];

            [csContent appendString:@"// Auto-generated dump.cs\n"];
            [csContent appendFormat:@"// Source: GameAssembly.dll (%zu classes)\n\n", classCount];
            [jsonContent appendString:@"{\n  \"ScriptMethod\": [\n"];

            int totalClasses = 0, totalMethods = 0, totalFields = 0;
            BOOL firstJson = YES;

            for (size_t i = 0; i < classCount; i++) {
                @autoreleasepool {
                    @try {
                        Il2CppClass *klass = [r image_get_class:targetImage index:i];
                        if (!klass || (uintptr_t)klass < 0x1000) continue;

                        const char *cname = [r class_get_name:klass];
                        if (!cname) continue;
                        NSString *clsName = [NSString stringWithUTF8String:cname];
                        if (!clsName || clsName.length == 0) continue;

                        const char *cns = [r class_get_namespace:klass];
                        NSString *nsName = (cns && [NSString stringWithUTF8String:cns])
                                          ? [NSString stringWithUTF8String:cns] : @"";

                        // Parent
                        NSString *parentName = @"";
                        @try {
                            Il2CppClass *parent = [r class_get_parent:klass];
                            if (parent && (uintptr_t)parent >= 0x1000) {
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

                        if (parentName.length > 0 && ![parentName isEqualToString:@"Object"]) {
                            [csContent appendFormat:@"public class %@ : %@ {\n", clsName, parentName];
                        } else {
                            [csContent appendFormat:@"public class %@ {\n", clsName];
                        }

                        // Fields
                        uint16_t fCount = 0;
                        NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

                        if (fCount > 0) {
                            [csContent appendString:@"    // Fields\n"];
                        }

                        for (uint16_t j = 0; j < fCount; j++) {
                            @try {
                                FieldInfo *fi = (FieldInfo *)fList[j].pointerValue;
                                if (!fi || (uintptr_t)fi < 0x1000) continue;

                                const char *fn = [r field_get_name:fi];
                                if (!fn) continue;
                                NSString *fieldName = [NSString stringWithUTF8String:fn];
                                if (!fieldName) continue;

                                size_t off = (size_t)[r field_get_offset:fi];

                                [csContent appendFormat:@"    public void* %@; // 0x%zX\n",
                                 fieldName, off];
                                totalFields++;
                            } @catch (NSException *e) {}
                        }

                        // Methods
                        uint16_t mCount = 0;
                        NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];

                        if (mCount > 0) {
                            [csContent appendString:@"\n    // Methods\n"];
                        }

                        for (uint16_t j = 0; j < mCount; j++) {
                            @try {
                                MethodInfo *mi = (MethodInfo *)mList[j].pointerValue;
                                if (!mi || (uintptr_t)mi < 0x1000) continue;

                                const char *mn = [r method_get_name:mi];
                                if (!mn) continue;
                                NSString *methodName = [NSString stringWithUTF8String:mn];
                                if (!methodName || methodName.length == 0) continue;

                                void *ptr = [r method_get_pointer:mi];
                                uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                                uint32_t token = [r method_get_token:mi];

                                uint32_t mflags = [r method_get_flags:mi];
                                BOOL isStatic = (mflags & 0x0010) != 0;
                                NSString *modifier = isStatic ? @"public static" : @"public";

                                [csContent appendFormat:@"    %@ void %@(); // RVA: 0x%llX Token: 0x%X\n",
                                 modifier, methodName, rva, token];

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

                        [csContent appendString:@"}\n"];
                        if (nsName.length > 0) [csContent appendString:@"}\n"];
                        [csContent appendString:@"\n"];

                        totalClasses++;
                    } @catch (NSException *e) {}
                }

                // Cập nhật progress mỗi 200 class
                if (i % 200 == 0) {
                    float p = 0.05f + 0.9f * ((float)i / classCount);
                    progress(p, [NSString stringWithFormat:@"%d/%zu class — %d method",
                                 totalClasses, classCount, totalMethods]);
                }
            }

            [jsonContent appendString:@"\n  ],\n"];

            uint64_t baseAddr = (uint64_t)(uintptr_t)_dyld_get_image_header(0);
            [jsonContent appendFormat:
                @"  \"ScriptMetadata\": {\n"
                @"    \"ExecutableName\": \"UnityFramework\",\n"
                @"    \"Address\": %llu,\n"
                @"    \"Metadata\": \"global-metadata.dat\"\n"
                @"  }\n",
                baseAddr];
            [jsonContent appendString:@"}\n"];

            // ===== Ghi file =====
            NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSString *outDir = [docs stringByAppendingPathComponent:@"IL2CPP_Dump"];
            [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                      withIntermediateDirectories:YES attributes:nil error:nil];

            NSString *csPath     = [outDir stringByAppendingPathComponent:@"dump.cs"];
            NSString *scriptPath = [outDir stringByAppendingPathComponent:@"script.json"];

            [[NSFileManager defaultManager] removeItemAtPath:csPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:scriptPath error:nil];

            [csContent writeToFile:csPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [jsonContent writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

            // ===== Thống kê =====
            unsigned long long sizeCs = 0, sizeJ = 0;
            NSDictionary *a1 = [[NSFileManager defaultManager] attributesOfItemAtPath:csPath error:nil];
            NSDictionary *a2 = [[NSFileManager defaultManager] attributesOfItemAtPath:scriptPath error:nil];
            if (a1) sizeCs = [a1 fileSize];
            if (a2) sizeJ = [a2 fileSize];

            NSLog(@"[Dumper] DONE: %d class, %d method, %d field",
                  totalClasses, totalMethods, totalFields);

            int total = totalClasses, methods = totalMethods, fields = totalFields;
            NSString *outDirCopy = outDir;
            unsigned long long sCs = sizeCs, sJ = sizeJ;

            dispatch_async(dispatch_get_main_queue(), ^{
                ws.progressView.progress = 1.0;
                ws.statusLabel.text = (total > 0) ? @"Dump hoan thanh!" : @"0 class";
                ws.statusLabel.textColor = (total > 0) ? [ToolTheme shared].success : [ToolTheme shared].warning;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
                ws.isDumping = NO;

                ws.resultLabel.text = [NSString stringWithFormat:
                    @"Luu vao: %@\n\n"
                    @"GameAssembly.dll\n"
                    @"%d class, %d method, %d field\n\n"
                    @"dump.cs: %@\nscript.json: %@",
                    outDirCopy, total, methods, fields,
                    [NSByteCountFormatter stringFromByteCount:(long long)sCs countStyle:NSByteCountFormatterCountStyleFile],
                    [NSByteCountFormatter stringFromByteCount:(long long)sJ countStyle:NSByteCountFormatterCountStyleFile]];
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
