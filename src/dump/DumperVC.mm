#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"
#import <mach-o/dyld.h>

@interface DumperVC ()
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UISwitch *genScriptSwitch;
@property (nonatomic, strong) UISwitch *genHeaderSwitch;
@property (nonatomic, strong) UISwitch *genCsSwitch;
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
    sub.text = @"Dump mỗi .dll thành 1 file riêng";
    sub.textColor = [ToolTheme shared].textMuted;
    sub.font = [[ToolTheme shared] monoFont:10];
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
    [self.dumpButton addTarget:self action:@selector(startDump)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.dumpButton];
    y += 56;

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

    self.resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 100)];
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

- (UISwitch *)addRow:(NSString *)title desc:(NSString *)desc y:(CGFloat)y {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 52)];
    row.backgroundColor = [ToolTheme shared].surface;
    row.layer.cornerRadius = 6;
    [self.view addSubview:row];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 100, 18)];
    t.text = title;
    t.textColor = [ToolTheme shared].textPrimary;
    t.font = [[ToolTheme shared] monoBoldFont:12];
    [row addSubview:t];

    UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(12, 28, w - 100, 16)];
    d.text = desc;
    d.textColor = [ToolTheme shared].textMuted;
    d.font = [[ToolTheme shared] monoFont:10];
    [row addSubview:d];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(CGRectGetWidth(row.bounds) - 60, 11, 51, 31)];
    sw.onTintColor = [ToolTheme shared].accent;
    sw.on = YES;
    [row addSubview:sw];
    return sw;
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

    BOOL doScript = self.genScriptSwitch.isOn;
    BOOL doHeader = self.genHeaderSwitch.isOn;
    BOOL doCs     = self.genCsSwitch.isOn;

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
            if (!r) { fail(@"Loi: resolver nil"); return; }
            if (![r resolve]) { fail(@"Loi: IL2CPP not resolved"); return; }
            NSLog(@"[Dumper] resolve OK");

            Il2CppDomain *domain = [r domain_get];
            if (!domain) { fail(@"Loi: No domain"); return; }
            NSLog(@"[Dumper] domain OK");

            if (domain->assembly_count <= 0 || domain->assemblies == NULL) {
                fail(@"Loi: assembly_count = 0");
                return;
            }
            NSLog(@"[Dumper] assembly_count = %zu", domain->assembly_count);

            NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSString *outDir = [docs stringByAppendingPathComponent:@"IL2CPP_Dump"];
            NSString *dumpDir = [outDir stringByAppendingPathComponent:@"Dump"];
            [[NSFileManager defaultManager] createDirectoryAtPath:dumpDir
                                      withIntermediateDirectories:YES attributes:nil error:nil];

            [[NSFileManager defaultManager] removeItemAtPath:dumpDir error:nil];
            [[NSFileManager defaultManager] createDirectoryAtPath:dumpDir
                                      withIntermediateDirectories:YES attributes:nil error:nil];

            NSString *scriptPath = [outDir stringByAppendingPathComponent:@"script.json"];
            NSString *headerPath = [outDir stringByAppendingPathComponent:@"il2cpp.h"];

            [[NSFileManager defaultManager] removeItemAtPath:scriptPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:headerPath error:nil];

            NSMutableArray *scriptMethods = [NSMutableArray array];

            NSMutableString *headerContent = [NSMutableString string];
            [headerContent appendString:@"// Auto-generated il2cpp.h\n#pragma once\n#include <stdint.h>\n\n"];

            int totalClasses = 0;
            int totalMethods = 0;
            int totalFields = 0;
            int dumpedImages = 0;

            NSMutableArray<NSString *> *dumpedFiles = [NSMutableArray array];

            int maxAssemblies = (int)domain->assembly_count;

            for (int a = 0; a < maxAssemblies; a++) {
                @autoreleasepool {
                    @try {
                        Il2CppAssembly *asm_ = domain->assemblies[a];
                        if (!asm_) continue;
                        if ((uintptr_t)asm_ < 0x1000) continue;

                        Il2CppImage *image = [r assembly_get_image:asm_];
                        if (!image) continue;
                        if ((uintptr_t)image < 0x1000) continue;

                        const char *imgNameC = [r image_get_name:image];
                        if (!imgNameC) continue;
                        NSString *imgName = [NSString stringWithUTF8String:imgNameC];
                        if (!imgName) continue;

                        size_t classCount = [r image_get_class_count:image];
                        if (classCount == 0) continue;

                        NSLog(@"[Dumper] DUMP %@ (%zu classes)", imgName, classCount);
                        progress(0.05f + 0.9f * ((float)a / maxAssemblies),
                                 [NSString stringWithFormat:@"DUMP %@ (%zu class)", imgName, classCount]);

                        dumpedImages++;

                        NSString *safeName = [imgName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
                        safeName = [safeName stringByReplacingOccurrencesOfString:@":" withString:@"_"];
                        NSString *imageCsPath = [dumpDir stringByAppendingPathComponent:
                                                 [NSString stringWithFormat:@"%@.cs", safeName]];

                        [[NSFileManager defaultManager] removeItemAtPath:imageCsPath error:nil];
                        [[NSFileManager defaultManager] createFileAtPath:imageCsPath
                                                                contents:[NSData data]
                                                              attributes:nil];
                        NSFileHandle *imageFH = [NSFileHandle fileHandleForWritingAtPath:imageCsPath];

                        if (imageFH) {
                            NSString *header = [NSString stringWithFormat:
                                @"// Auto-generated dump for %@\n"
                                @"// Image index: %d\n"
                                @"// Class count: %zu\n\n",
                                imgName, a, classCount];
                            [imageFH writeData:[header dataUsingEncoding:NSUTF8StringEncoding]];
                        }

                        [headerContent appendFormat:@"\n// Image %d: %@\n", a, imgName];

                        for (size_t i = 0; i < classCount; i++) {
                            @autoreleasepool {
                                @try {
                                    Il2CppClass *klass = [r image_get_class:image index:i];
                                    if (!klass) continue;
                                    if ((uintptr_t)klass < 0x1000) continue;

                                    const char *cname = [r class_get_name:klass];
                                    if (!cname) continue;
                                    NSString *clsName = [NSString stringWithUTF8String:cname];
                                    if (!clsName || clsName.length == 0) continue;

                                    const char *cns = [r class_get_namespace:klass];
                                    NSString *nsName = (cns && [NSString stringWithUTF8String:cns])
                                                      ? [NSString stringWithUTF8String:cns] : @"";

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
                                    } @catch (NSException *e) { parentName = @""; }

                                    // ============ dump.cs ============
                                    if (imageFH) {
                                        NSMutableString *cs = [NSMutableString string];

                                        if (nsName.length > 0) {
                                            [cs appendFormat:@"namespace %@ {\n", nsName];
                                        }

                                        if (parentName.length > 0 && ![parentName isEqualToString:@"Object"]) {
                                            [cs appendFormat:@"public class %@ : %@ {\n", clsName, parentName];
                                        } else {
                                            [cs appendFormat:@"public class %@ {\n", clsName];
                                        }

                                        uint16_t fCount = 0;
                                        NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

                                        if (fCount > 0) {
                                            [cs appendString:@"    // Fields\n"];
                                        }

                                        for (uint16_t j = 0; j < fCount; j++) {
                                            @try {
                                                FieldInfo *fi = (FieldInfo *)fList[j].pointerValue;
                                                if (!fi) continue;
                                                if ((uintptr_t)fi < 0x1000) continue;

                                                const char *fn = [r field_get_name:fi];
                                                if (!fn) continue;
                                                NSString *fieldName = [NSString stringWithUTF8String:fn];
                                                if (!fieldName) continue;

                                                int32_t off = [r field_get_offset:fi];

                                                NSString *typeName = @"void*";
                                                const char *tn = [r field_get_type_name:fi];
                                                if (tn) {
                                                    NSString *t = [NSString stringWithUTF8String:tn];
                                                    if (t && t.length > 0) typeName = t;
                                                }

                                                [cs appendFormat:@"    public %@ %@; // 0x%X\n",
                                                 typeName, fieldName, off];
                                                totalFields++;
                                            } @catch (NSException *e) {}
                                        }

                                        uint16_t mCount = 0;
                                        NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];

                                        if (mCount > 0) {
                                            [cs appendString:@"\n    // Methods\n"];
                                        }

                                        for (uint16_t j = 0; j < mCount; j++) {
                                            @try {
                                                MethodInfo *mi = (MethodInfo *)mList[j].pointerValue;
                                                if (!mi) continue;
                                                if ((uintptr_t)mi < 0x1000) continue;

                                                const char *mn = [r method_get_name:mi];
                                                if (!mn) continue;
                                                NSString *methodName = [NSString stringWithUTF8String:mn];
                                                if (!methodName || methodName.length == 0) continue;

                                                void *ptr = [r method_get_pointer:mi];
                                                uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                                                uint32_t token = [r method_get_token:mi];

                                                NSString *retType = @"void";
                                                const char *rt = [r method_get_return_type:mi];
                                                if (rt) {
                                                    NSString *t = [NSString stringWithUTF8String:rt];
                                                    if (t && t.length > 0) retType = t;
                                                }

                                                uint32_t mflags = [r method_get_flags:mi];
                                                BOOL isStatic = (mflags & 0x0010) != 0;
                                                NSString *modifier = isStatic ? @"public static" : @"public";

                                                [cs appendFormat:@"    %@ %@ %@(); // RVA: 0x%llX Token: 0x%X\n",
                                                 modifier, retType, methodName, rva, token];

                                                totalMethods++;

                                                if (rva > 0) {
                                                    NSString *fullName = nsName.length > 0
                                                        ? [NSString stringWithFormat:@"%@.%@$$%@", nsName, clsName, methodName]
                                                        : [NSString stringWithFormat:@"%@$$%@", clsName, methodName];
                                                    [scriptMethods addObject:@{
                                                        @"Address": @(rva),
                                                        @"Name": fullName,
                                                    }];
                                                }
                                            } @catch (NSException *e) {}
                                        }

                                        [cs appendString:@"}\n"];
                                        if (nsName.length > 0) [cs appendString:@"}\n"];
                                        [cs appendString:@"\n"];

                                        [imageFH writeData:[cs dataUsingEncoding:NSUTF8StringEncoding]];
                                    }

                                    // ============ il2cpp.h ============
                                    if (doHeader) {
                                        NSString *full = nsName.length > 0
                                            ? [NSString stringWithFormat:@"%@_%@", nsName, clsName] : clsName;
                                        full = [full stringByReplacingOccurrencesOftableString:@"." withString:@"_"];
                                        full =;\ [full stringByReplacingOccurnrencesOfString:@"`" with"];
String:@"_"];
                                        full = [full                                        stringByReplacingOccurrencesOfString:@"<" withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@">" withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                                        full = [full stringByReplacingOccurrencesOfString:@"-" withString:@"_"];

                                        NSMutableString *hs = [NSMutableString string];
                                        [hs appendFormat:@"struct %@_t {\n", full];
                                        [hs appendString:@"    void *v [hs appendString:@"    void *monitor;\n"];

                                        uint16_t fCount2 = 0;
                                        NSArray<NSValue *> *fList2 = [r class_get_fields:klass count:&fCount2];
                                        for (uint16_t j = 0; j < fCount2; j++) {
                                            @try {
                                                FieldInfo *fi = (FieldInfo *)fList2[j].pointerValue;
                                                if (!fi) continue;
                                                if ((uintptr_t)fi < 0x1000) continue;
                                                const char *fn = [r field_get_name:fi];
                                                if (!fn) continue;
                                                int32_t off = [r field_get_offset:fi];
                                                NSString *fnStr = [NSString stringWithUTF8String:fn];
                                                if (!fnStr) continue;
                                                fnStr = [fnStr stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                                                [hs appendFormat:@"    uint8_t _field_%@[0x%X]; // offset 0x%X\n",
                                                 fnStr, off, off];
                                            } @catch (NSException *e) {}
                                        }

                                        [hs appendString:@"};\n\n"];
                                        [headerContent appendString:hs];
                                    }

                                    totalClasses++;

                                    if (totalClasses % 100 == 0) {
                                        float p = (float)totalClasses / 20000.0f;
                                        if (p > 0.95f) p = 0.95f;
                                        NSString *status = [NSString stringWithFormat:
                                            @"%@ — %d class, %d method, %d field",
                                            imgName, totalClasses, totalMethods, totalFields];
                                        progress(p, status);
                                    }
                                } @catch (NSException *e) {
                                    // skip class lỗi
                                }
                            }
                        }

                        if (imageFH) {
                            [imageFH closeFile];
                            [dumpedFiles addObject:imageCsPath];
                        }

                    } @catch (NSException *e) {
                        NSLog(@"[Dumper] assembly %d exception: %@", a, e);
                    }
                }
            }

            // ===== Ghi script.json =====
            if (doScript) {
                NSMutableString *json = [NSMutableString string];
                [json appendString:@"{\n"];
                [json appendString:@"  \"ScriptMethod\": [\n"];

                for (NSUInteger i = 0; i < scriptMethods.count; i++) {
                    NSDictionary *m = scriptMethods[i];
                    [json appendFormat:@"    {\"Address\": %@, \"Name\": \"%@\"}",
                     m[@"Address"], m[@"Name"]];
                    if (i < scriptMethods.count - 1) {
                        [json appendString:@",\n"];
                    } else {
                        [json appendString:@"\n"];
                    }
                }

                [json appendString:@"  ],\n"];

                uint64_t baseAddr = (uint64_t)(uintptr_t)_dyld_get_image_header(0);
                [json appendFormat:
                    @"  \"ScriptMetadata\": {\n"
                    @"    \"ExecutableName\": \"UnityFramework\",\n"
                    @"    \"Address\": %llu,\n"
                    @"    \"Metadata\": \"global-metadata.dat\"\n"
                    @"  }\n",
                    baseAddr];
                [json appendString:@"}\n"];

                [json writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }

            // ===== Ghi il2cpp.h =====
            if (doHeader) {
                [headerContent writeToFile:headerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }

            NSLog(@"[Dumper] DONE: %d class, %d method, %d field (%d images)",
                  totalClasses, totalMethods, totalFields, dumpedImages);

            unsigned long long totalSize = 0;
            for (NSString *path in dumpedFiles) {
                NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
                if (attrs) totalSize += [attrs fileSize];
            }

            int total = totalClasses;
            int methods = totalMethods;
            int fields = totalFields;
            int images = dumpedImages;
            NSString *outDirCopy = outDir;
            NSString *dumpDirCopy = dumpDir;
            unsigned long long totalSizeCopy = totalSize;

            dispatch_async(dispatch_get_main_queue(), ^{
                ws.progressView.progress = 1.0;
                ws.statusLabel.text = (total > 0) ? @"Dump hoan thanh!" : @"Dump xong nhung 0 class";
                ws.statusLabel.textColor = (total > 0) ? [ToolTheme shared].success : [ToolTheme shared].warning;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
                ws.isDumping = NO;

                NSString *result = [NSString stringWithFormat:
                    @"Luu vao: %@\n\n"
                    @"%d image, %d class, %d method, %d field\n\n"
                    @"Tong dung luong: %@",
                    dumpDirCopy,
                    images, total, methods, fields,
                    [NSByteCountFormatter stringFromByteCount:(long long)totalSizeCopy
                                                   countStyle:NSByteCountFormatterCountStyleFile]];
                ws.resultLabel.text = result;
            });

        } @catch (NSException *e) {
            NSLog(@"[Dumper] NSException: %@", e);
            fail([NSString stringWithFormat:@"Exception: %@", e.reason]);
        } @catch (...) {
            NSLog(@"[Dumper] unknown exception");
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
