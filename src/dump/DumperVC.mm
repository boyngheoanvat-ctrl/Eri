#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

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
    sub.text = @"Dump ra: script.json + il2cpp.h + dump.cs";
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
    // Chống bấm 2 lần
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
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.statusLabel.text = msg;
                ws.statusLabel.textColor = [ToolTheme shared].danger;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
                ws.isDumping = NO;
            });
        };

        IL2CPPResolver *r = [IL2CPPResolver shared];

        if (!r || ![r resolve]) { fail(@"Loi: IL2CPP not resolved"); return; }

        Il2CppDomain *domain = [r domain_get];
        if (!domain) { fail(@"Loi: No domain (symbol dlsym fail?)"); return; }

        if (domain->assembly_count <= 0 || domain->assemblies == NULL) {
            fail(@"Loi: assembly_count = 0");
            return;
        }

        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *outDir = [docs stringByAppendingPathComponent:@"IL2CPP_Dump"];
        [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                  withIntermediateDirectories:YES attributes:nil error:nil];

        int maxAssemblies = MIN((int)domain->assembly_count, 2);
        int maxClasses    = 1000;

        NSString *scriptPath = [outDir stringByAppendingPathComponent:@"script.json"];
        NSString *headerPath = [outDir stringByAppendingPathComponent:@"il2cpp.h"];
        NSString *csPath     = [outDir stringByAppendingPathComponent:@"dump.cs"];

        if (doScript) [[NSFileManager defaultManager] createFileAtPath:scriptPath contents:[NSData data] attributes:nil];
        if (doHeader) [[NSFileManager defaultManager] createFileAtPath:headerPath contents:[NSData data] attributes:nil];
        if (doCs)     [[NSFileManager defaultManager] createFileAtPath:csPath     contents:[NSData data] attributes:nil];

        NSFileHandle *scriptFH = doScript ? [NSFileHandle fileHandleForWritingAtPath:scriptPath] : nil;
        NSFileHandle *headerFH = doHeader ? [NSFileHandle fileHandleForWritingAtPath:headerPath] : nil;
        NSFileHandle *csFH     = doCs     ? [NSFileHandle fileHandleForWritingAtPath:csPath]     : nil;

        if (scriptFH) [scriptFH writeData:[@"[\n" dataUsingEncoding:NSUTF8StringEncoding]];
        if (headerFH) [headerFH writeData:[@"// Auto-generated il2cpp.h\n#pragma once\n#include <stdint.h>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
        if (csFH)     [csFH writeData:[@"// Auto-generated dump.cs\n\n" dataUsingEncoding:NSUTF8StringEncoding]];

        __block int totalClasses = 0;
        __block BOOL firstJson = YES;
        __block int skippedAssemblies = 0;

        for (int a = 0; a < maxAssemblies; a++) {
            @autoreleasepool {
                Il2CppAssembly *asm_ = domain->assemblies[a];
                if (!asm_) { skippedAssemblies++; continue; }

                Il2CppImage *image = [r assembly_get_image:asm_];
                if (!image) {
                    // Không lấy được image (symbol fail) -> skip, KHÔNG deref mù
                    skippedAssemblies++;
                    continue;
                }

                const char *imgNameC = [r image_get_name:image];
                if (!imgNameC) { skippedAssemblies++; continue; }

                NSString *imgName = [NSString stringWithUTF8String:imgNameC];
                if (!imgName) { skippedAssemblies++; continue; }

                size_t classCount = [r image_get_class_count:image];
                if (classCount == 0) continue;

                size_t maxThisAssembly = MIN(classCount, (size_t)maxClasses);

                for (size_t i = 0; i < maxThisAssembly && totalClasses < maxClasses; i++) {
                    @autoreleasepool {
                        Il2CppClass *klass = [r image_get_class:image index:i];
                        if (!klass) continue;

                        const char *cname = [r class_get_name:klass];
                        if (!cname) continue;

                        NSString *clsName = [NSString stringWithUTF8String:cname];
                        if (!clsName) continue;

                        const char *cns = [r class_get_namespace:klass];
                        NSString *nsName = (cns && [NSString stringWithUTF8String:cns])
                                          ? [NSString stringWithUTF8String:cns] : @"";

                        // script.json
                        if (scriptFH) {
                            NSMutableString *jsonEntry = [NSMutableString string];
                            if (!firstJson) [jsonEntry appendString:@",\n"];
                            firstJson = NO;
                            NSString *safeCls = [clsName stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                            NSString *safeNs  = [nsName  stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                            NSString *safeImg = [imgName stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                            [jsonEntry appendFormat:@"  {\"Name\":\"%@\",\"Namespace\":\"%@\",\"Image\":\"%@\"}",
                             safeCls, safeNs, safeImg];
                            [scriptFH writeData:[jsonEntry dataUsingEncoding:NSUTF8StringEncoding]];
                        }

                        // il2cpp.h
                        if (headerFH) {
                            NSString *full = nsName.length > 0
                                ? [NSString stringWithFormat:@"%@_%@", nsName, clsName] : clsName;
                            full = [full stringByReplacingOccurrencesOfString:@"." withString:@"_"];
                            full = [full stringByReplacingOccurrencesOfString:@"`" withString:@"_"];
                            full = [full stringByReplacingOccurrencesOfString:@"<" withString:@"_"];
                            full = [full stringByReplacingOccurrencesOfString:@">" withString:@"_"];
                            NSString *line = [NSString stringWithFormat:
                                @"typedef struct %@ { void *vtable; void *monitor; } %@;\n", full, full];
                            [headerFH writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
                        }

                        // dump.cs
                        if (csFH) {
                            NSMutableString *cs = [NSMutableString string];
                            if (nsName.length > 0) [cs appendFormat:@"namespace %@ {\n", nsName];
                            [cs appendFormat:@"class %@ {\n", clsName];

                            // Methods
                            uint16_t mCount = 0;
                            NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
                            uint16_t maxM = (uint16_t)MIN((NSUInteger)mCount, (NSUInteger)10);
                            for (uint16_t j = 0; j < maxM; j++) {
                                MethodInfo *mi = (MethodInfo *)mList[j].pointerValue;
                                if (!mi) continue;
                                const char *mn = [r method_get_name:mi];
                                if (!mn) continue;
                                uint32_t token = [r method_get_token:mi];
                                void *ptr = [r method_get_pointer:mi];
                                uint64_t rva = (uint64_t)((uintptr_t)ptr);
                                [cs appendFormat:@"  void %s(); // RVA: 0x%llX Token: 0x%X\n", mn, rva, token];
                            }

                            // Fields
                            uint16_t fCount = 0;
                            NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];
                            uint16_t maxF = (uint16_t)MIN((NSUInteger)fCount, (NSUInteger)10);
                            for (uint16_t j = 0; j < maxF; j++) {
                                FieldInfo *fi = (FieldInfo *)fList[j].pointerValue;
                                if (!fi) continue;
                                const char *fn = [r field_get_name:fi];
                                if (!fn) continue;
                                int32_t off = [r field_get_offset:fi];
                                [cs appendFormat:@"  void *%s; // Offset: 0x%X\n", fn, off];
                            }

                            [cs appendString:@"}\n"];
                            if (nsName.length > 0) [cs appendString:@"}\n"];
                            [cs appendString:@"\n"];
                            [csFH writeData:[cs dataUsingEncoding:NSUTF8StringEncoding]];
                        }

                        totalClasses++;
                    }
                }
            }

            int aCopy = a;
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.progressView.progress = (CGFloat)(aCopy + 1) / maxAssemblies;
                ws.statusLabel.text = [NSString stringWithFormat:@"Quet %d/%d", aCopy + 1, maxAssemblies];
            });
        }

        if (scriptFH) {
            [scriptFH writeData:[@"\n]\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [scriptFH closeFile];
        }
        if (headerFH) [headerFH closeFile];
        if (csFH)     [csFH closeFile];

        int total = totalClasses;
        int skipped = skippedAssemblies;
        dispatch_async(dispatch_get_main_queue(), ^{
            ws.progressView.progress = 1.0;
            ws.statusLabel.text = (total > 0) ? @"Dump hoan thanh!" : @"Dump xong nhung 0 class";
            ws.statusLabel.textColor = (total > 0) ? [ToolTheme shared].success : [ToolTheme shared].warning;
            ws.dumpButton.enabled = YES;
            [ws.spinner stopAnimating];
            ws.isDumping = NO;
            ws.resultLabel.text = [NSString stringWithFormat:
                @"Da luu vao:\n%@\n\nTong: %d class\nBo qua: %d assembly\n\nNeu 0 class: kiem tra dlsym il2cpp_*",
                outDir, total, skipped];
        });
    });
}

- (void)reload {
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.isDumping = NO;
}

@end
