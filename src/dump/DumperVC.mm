#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

@interface DumperVC ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UISwitch *genScriptSwitch;
@property (nonatomic, strong) UISwitch *genHeaderSwitch;
@property (nonatomic, strong) UISwitch *compressSwitch;
@property (nonatomic, strong) UILabel *resultLabel;
@end

@implementation DumperVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 20;

    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 30)];
    title.text = @"IL2CPP Dumper";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    [self.view addSubview:title];
    y += 40;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 20)];
    sub.text = @"Output: script.json + il2cpp.h + DummyDll";
    sub.textColor = [ToolTheme shared].textMuted;
    sub.font = [[ToolTheme shared] monoFont:11];
    [self.view addSubview:sub];
    y += 40;

    // Toggle rows
    self.genScriptSwitch = [self addToggleRow:@"script.json" desc:@"IDA/Ghidra helper" y:y];
    y += 64;
    self.genHeaderSwitch = [self addToggleRow:@"il2cpp.h" desc:@"C header with offsets" y:y];
    y += 64;
    self.compressSwitch = [self addToggleRow:@"Zip archive" desc:@"Create .zip after dump" y:y];
    y += 80;

    // Dump button
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
    y += 60;

    // Progress
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(16, y, w - 32, 4)];
    self.progressView.progressTintColor = [ToolTheme shared].accent;
    self.progressView.hidden = YES;
    [self.view addSubview:self.progressView];
    y += 16;

    // Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 20)];
    self.statusLabel.text = @"Ready";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.statusLabel.font = [[ToolTheme shared] monoFont:11];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    y += 30;

    // Result
    self.resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 100)];
    self.resultLabel.text = @"";
    self.resultLabel.textColor = [ToolTheme shared].textSecondary;
    self.resultLabel.font = [[ToolTheme shared] monoFont:10];
    self.resultLabel.numberOfLines = 0;
    [self.view addSubview:self.resultLabel];
}

- (UISwitch *)addToggleRow:(NSString *)title desc:(NSString *)desc y:(CGFloat)y {
    CGFloat w = CGRectGetWidth(self.view.bounds);

    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 56)];
    row.backgroundColor = [ToolTheme shared].surface;
    row.layer.cornerRadius = 6;
    [self.view addSubview:row];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 100, 20)];
    t.text = title;
    t.textColor = [ToolTheme shared].textPrimary;
    t.font = [[ToolTheme shared] monoBoldFont:13];
    [row addSubview:t];

    UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(12, 28, w - 100, 18)];
    d.text = desc;
    d.textColor = [ToolTheme shared].textMuted;
    d.font = [[ToolTheme shared] monoFont:10];
    [row addSubview:d];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(CGRectGetWidth(row.bounds) - 60, 12, 51, 31)];
    sw.onTintColor = [ToolTheme shared].accent;
    sw.on = YES;
    [row addSubview:sw];

    return sw;
}

- (void)startDump {
    self.progressView.hidden = NO;
    self.progressView.progress = 0;
    self.statusLabel.text = @"Dumping...";
    self.statusLabel.textColor = [ToolTheme shared].warning;
    self.dumpButton.enabled = NO;
    self.resultLabel.text = @"";

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        IL2CPPResolver *r = [IL2CPPResolver shared];
        if (![r resolve]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = @"Error: IL2CPP not resolved";
                self.statusLabel.textColor = [ToolTheme shared].danger;
                self.dumpButton.enabled = YES;
            });
            return;
        }

        Il2CppDomain *domain = [r domain_get];
        if (!domain) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = @"Error: No domain";
                self.statusLabel.textColor = [ToolTheme shared].danger;
                self.dumpButton.enabled = YES;
            });
            return;
        }

        // Collect all classes
        NSMutableArray *allClasses = [NSMutableArray array];
        for (int a = 0; a < domain->assembly_count; a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            void *imgPtr = *(void **)asm_;
            if (!imgPtr) continue;
            Il2CppImage *image = (Il2CppImage *)imgPtr;
            if (!image || !image->name) continue;

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
                    @"image": [NSString stringWithUTF8String:image->name],
                    @"klass": [NSValue valueWithPointer:(void *)klass]
                }];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.progressView.progress = (CGFloat)(a + 1) / domain->assembly_count;
                self.statusLabel.text = [NSString stringWithFormat:@"Scanning %d/%d", a + 1, domain->assembly_count];
            });
        }

        // Save to Documents
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *outDir = [docs stringByAppendingPathComponent:@"IL2CPP_Dump"];
        [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        // Write script.json
        if (self.genScriptSwitch.isOn) {
            NSMutableArray *jsonOut = [NSMutableArray array];
            for (NSDictionary *info in allClasses) {
                [jsonOut addObject:@{
                    @"Name": info[@"name"],
                    @"Namespace": info[@"namespace"],
                    @"Image": info[@"image"]
                }];
            }
            NSData *data = [NSJSONSerialization dataWithJSONObject:jsonOut
                                                            options:NSJSONWritingPrettyPrinted
                                                              error:nil];
            [data writeToFile:[outDir stringByAppendingPathComponent:@"script.json"] atomically:YES];
        }

        // Write il2cpp.h
        if (self.genHeaderSwitch.isOn) {
            NSMutableString *h = [NSMutableString string];
            [h appendString:@"// Auto-generated il2cpp.h\n#pragma once\n#include <stdint.h>\n\n"];
            for (NSDictionary *info in allClasses) {
                NSString *name = info[@"name"];
                NSString *ns = info[@"namespace"];
                NSString *full = ns.length > 0 ? [NSString stringWithFormat:@"%@_%@", ns, name] : name;
                full = [full stringByReplacingOccurrencesOfString:@"." withString:@"_"];
                full = [full stringByReplacingOccurrencesOfString:@"`" withString:@"_"];
                [h appendFormat:@"typedef struct %@ { void *vtable; void *monitor; } %@;\n", full, full];
            }
            [h writeToFile:[outDir stringByAppendingPathComponent:@"il2cpp.h"]
                atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = 1.0;
            self.statusLabel.text = @"Dump completed!";
            self.statusLabel.textColor = [ToolTheme shared].success;
            self.dumpButton.enabled = YES;
            self.resultLabel.text = [NSString stringWithFormat:@"Saved to:\n%@\n\nTotal: %lu classes",
                                     outDir, (unsigned long)allClasses.count];
        });
    });
}

- (void)reload {
    self.statusLabel.text = @"Ready";
    self.statusLabel.textColor = [ToolTheme shared].success;
}

@end
