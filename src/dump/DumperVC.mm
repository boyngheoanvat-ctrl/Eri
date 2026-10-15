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
@property (nonatomic, strong) UILabel *debugLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL isDumping;
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
    [self.dumpButton addTarget:self action:@selector(startDump) forControlEvents:UIControlEventTouchUpInside];
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

- (void)startDump {
    if (self.isDumping) return;
    self.isDumping = YES;
    self.progressView.hidden = NO;
    self.progressView.progress = 0;
    self.statusLabel.text = @"Dang dump...";
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
            IL2CPPResolver *r = [IL2CPPResolver shared];
            if (!r || ![r resolve]) { fail(@"Loi: IL2CPP not resolved"); return; }
            uint64_t il2cppBase = [r il2cppBase];
            Il2CppDomain *domain = [r domain_get];
            if (!domain) { fail(@"Loi: No domain"); return; }

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

            NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSString *outDir = [docs stringByAppendingPathComponent:@"IL2CPP_Dump"];
            [[NSFileManager defaultManager] createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:nil];

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

            [csContent appendString:@"// Auto-generated dump.cs\n\n"];
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

                        [csContent appendFormat:@"\n// ============================================================\n// Image %d: %@ (%zu classes)\n// ============================================================\n\n", a, imgName, classCount];

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
                                    NSString *nsName = (cns && [NSString stringWithUTF8String:cns]) ? [NSString stringWithUTF8String:cns] : @"";

                                    if (nsName.length > 0) [csContent appendFormat:@"namespace %@ {\n", nsName];
                                    [csContent appendFormat:@"public class %@ {\n", clsName];

                                    uint16_t mCount = 0;
                                    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
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
                                            uint64_t rva = (va > il2cppBase && il2cppBase > 0) ? (va - il2cppBase) : va;
                                            uint32_t token = [r method_get_token:mi];

                                            // Định dạng chuẩn RVA / Offset / VA / Token
                                            [csContent appendFormat:@"    public void %@(); // RVA: 0x%llX Offset: 0x%llX VA: 0x%llX Token: 0x%X\n",
                                             methodName, rva, rva, va, token];
                                            totalMethods++;

                                            if (rva > 0) {
                                                if (!firstJson) [jsonContent appendString:@",\n"];
                                                firstJson = NO;
                                                NSString *fullName = nsName.length > 0 ? [NSString stringWithFormat:@"%@.%@$$%@", nsName, clsName, methodName] : [NSString stringWithFormat:@"%@$$%@", clsName, methodName];
                                                [jsonContent appendFormat:@"    {\"Address\": %llu, \"Name\": \"%@\"}", rva, fullName];
                                            }
                                        } @catch (NSException *e) {}
                                    }

                                    [csContent appendString:@"}\n"];
                                    if (nsName.length > 0) [csContent appendString:@"}\n"];
                                    totalClasses++;
                                } @catch (NSException *e) {}
                            }
                        }
                    } @catch (NSException *e) {}
                }
                float p = (float)(a + 1) / maxAssemblies;
                if (p > 0.95f) p = 0.95f;
                progress(p, [NSString stringWithFormat:@"Assembly %d/%d — %d class", a + 1, maxAssemblies, totalClasses]);
            }

            [jsonContent appendString:@"\n  ],\n"];
            [jsonContent appendString:@"  \"ScriptMetadata\": {\n    \"ExecutableName\": \"UnityFramework\"\n  }\n}\n"];

            if (doCs)     [csContent writeToFile:csPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            if (doHeader) [headerContent writeToFile:headerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            if (doScript) [jsonContent writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [stringsContent writeToFile:stringsPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
                ws.progressView.progress = 1.0;
                ws.statusLabel.text = @"Dump hoan thanh!";
                ws.statusLabel.textColor = [ToolTheme shared].success;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
                ws.isDumping = NO;
                ws.resultLabel.text = [NSString stringWithFormat:@"Đã lưu tại: %@\n%d image, %d class, %d method", outDir, totalImages, totalClasses, totalMethods];
            });
        } @catch (NSException *e) {
            fail([NSString stringWithFormat:@"Exception: %@", e.reason]);
        }
    });
}

- (void)reload {
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.isDumping = NO;
}

@end
