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

    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(16, y, w - 32, 4)];
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

- (void)startDump {
    self.progressView.hidden = NO;
    self.progressView.progress = 0;
    self.statusLabel.text = @"Dang dump...";
    self.statusLabel.textColor = [ToolTheme shared].warning;
    self.dumpButton.enabled = NO;
    self.resultLabel.text = @"";
    [self.spinner startAnimating];

    BOOL doScript = self.genScriptSwitch.isOn;
    BOOL doHeader = self.genHeaderSwitch.isOn;
    BOOL doCs = self.genCsSwitch.isOn;

    __weak typeof(self) ws = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            IL2CPPResolver *r = [IL2CPPResolver shared];
            if (![r resolve]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ws.statusLabel.text = @"Loi: IL2CPP not resolved";
                    ws.statusLabel.textColor = [ToolTheme shared].danger;
                    ws.dumpButton.enabled = YES;
                    [ws.spinner stopAnimating];
                });
                return;
            }

            Il2CppDomain *domain = [r domain_get];
            if (!domain) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ws.statusLabel.text = @"Loi: No domain";
                    ws.statusLabel.textColor = [ToolTheme shared].danger;
                    ws.dumpButton.enabled = YES;
                    [ws.spinner stopAnimating];
                });
                return;
            }

            NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSString *outDir = [docs stringByAppendingPathComponent:@"IL2CPP_Dump"];
            [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                      withIntermediateDirectories:YES attributes:nil error:nil];

            NSMutableArray *allClasses = [NSMutableArray array];

            for (int a = 0; a < domain->assembly_count; a++) {
                Il2CppAssembly *asm_ = domain->assemblies[a];
                if (!asm_) continue;
                void *imgPtr = *(void **)asm_;
                if (!imgPtr) continue;
                Il2CppImage *image = (Il2CppImage *)imgPtr;
                if (!image || !image->name) continue;

                NSString *imgName = [NSString stringWithUTF8String:image->name];
                size_t classCount = [r image_get_class_count:image];

                for (size_t i = 0; i < classCount; i++) {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    const char *cname = [r class_get_name:klass];
                    const char *cns = [r class_get_namespace:klass];
                    if (!cname) continue;

                    [allClasses addObject:@{
                        @"name": [NSString stringWithUTF8String:cname],
                        @"namespace": cns ? [NSString stringWithUTF8String:cns] : @"",
                        @"image": imgName,
                        @"klass": [NSValue valueWithPointer:(void *)klass]
                    }];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    ws.progressView.progress = (CGFloat)(a + 1) / domain->assembly_count;
                    ws.statusLabel.text = [NSString stringWithFormat:@"Quet %d/%d", a + 1, domain->assembly_count];
                });
            }

            // script.json
            if (doScript) {
                NSMutableArray *jsonOut = [NSMutableArray array];
                for (NSDictionary *info in allClasses) {
                    [jsonOut addObject:@{@"Name": info[@"name"], @"Namespace": info[@"namespace"], @"Image": info[@"image"]}];
                }
                NSData *data = [NSJSONSerialization dataWithJSONObject:jsonOut options:NSJSONWritingPrettyPrinted error:nil];
                [data writeToFile:[outDir stringByAppendingPathComponent:@"script.json"] atomically:YES];
            }

            // il2cpp.h
            if (doHeader) {
                NSMutableString *h = [NSMutableString string];
                [h appendString:@"// Auto-generated il2cpp.h\n#pragma once\n#include <stdint.h>\n\n"];
                for (NSDictionary *info in allClasses) {
                    NSString *name = info[@"name"];
                    NSString *ns = info[@"namespace"];
                    NSString *full = ns.length > 0 ? [NSString stringWithFormat:@"%@_%@", ns, name] : name;
                    full = [full stringByReplacingOccurrencesOfString:@"." withString:@"_"];
                    full = [full stringByReplacingOccurrencesOfString:@"`" withString:@"_"];
                    full = [full stringByReplacingOccurrencesOfString:@"<" withString:@"_"];
                    full = [full stringByReplacingOccurrencesOfString:@">" withString:@"_"];
                    [h appendFormat:@"typedef struct %@ { void *vtable; void *monitor; } %@;\n", full, full];
                }
                [h writeToFile:[outDir stringByAppendingPathComponent:@"il2cpp.h"]
                    atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }

            // dump.cs
            if (doCs) {
                NSMutableString *cs = [NSMutableString string];
                [cs appendString:@"// Auto-generated dump.cs\n"];
                [cs appendString:@"// IL2CPP Dump\n\n"];

                for (NSDictionary *info in allClasses) {
                    NSString *cls = info[@"name"];
                    NSString *ns = info[@"namespace"];

                    NSValue *klassValue = (NSValue *)info[@"klass"];
                    if (![klassValue isKindOfClass:[NSValue class]]) continue;
                    Il2CppClass *klass = (Il2CppClass *)klassValue.pointerValue;
                    if (!klass) continue;

                    if (ns.length > 0) [cs appendFormat:@"namespace %@ {\n", ns];
                    [cs appendFormat:@"class %@ {\n", cls];
                    [cs appendString:@"    // Methods\n"];

                    uint16_t mCount = 0;
                    const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
                    for (uint16_t j = 0; j < mCount; j++) {
                        const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
                        uint32_t token = [r method_get_token:(MethodInfo *)mList[j]];
                        void *ptr = [r method_get_pointer:(MethodInfo *)mList[j]];
                        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                        if (mn) {
                            [cs appendFormat:@"    void %s(); // RVA: 0x%llX Token: 0x%X\n", mn, rva, token];
                        }
                    }
                    if (mList) free(mList);

                    [cs appendString:@"\n    // Fields\n"];
                    uint16_t fCount = 0;
                    const FieldInfo **fList = [r class_get_fields:klass count:&fCount];
                    for (uint16_t j = 0; j < fCount; j++) {
                        const char *fn = [r field_get_name:(FieldInfo *)fList[j]];
                        int32_t off = [r field_get_offset:(FieldInfo *)fList[j]];
                        if (fn) {
                            [cs appendFormat:@"    void *%s; // Offset: 0x%X\n", fn, off];
                        }
                    }
                    if (fList) free(fList);

                    [cs appendString:@"}\n"];
                    if (ns.length > 0) [cs appendString:@"}\n"];
                    [cs appendString:@"\n"];
                }

                [cs writeToFile:[outDir stringByAppendingPathComponent:@"dump.cs"]
                     atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                ws.progressView.progress = 1.0;
                ws.statusLabel.text = @"Dump hoan thanh!";
                ws.statusLabel.textColor = [ToolTheme shared].success;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
                ws.resultLabel.text = [NSString stringWithFormat:@"Da luu vao:\n%@\n\nTong: %lu class",
                                        outDir, (unsigned long)allClasses.count];
            });

        } @catch (NSException *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.statusLabel.text = [NSString stringWithFormat:@"Loi: %@", e.reason];
                ws.statusLabel.textColor = [ToolTheme shared].danger;
                ws.dumpButton.enabled = YES;
                [ws.spinner stopAnimating];
            });
        }
    });
}

- (void)reload {
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].success;
}

@end
