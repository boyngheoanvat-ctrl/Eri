#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

@interface DumperVC ()
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UISwitch *scriptSwitch;
@property (nonatomic, strong) UISwitch *headerSwitch;
@property (nonatomic, strong) UISwitch *csSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@property (atomic, assign) BOOL isDumping;
@end

@implementation DumperVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat y = 16;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"IL2CPP Dumper & Ghidra RVA";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 40;

        self.scriptSwitch = [self addRow:@"script.json" desc:@"IDA / Ghidra helper" y:y];
        y += 60;
        self.headerSwitch = [self addRow:@"il2cpp.h" desc:@"C header structures" y:y];
        y += 60;
        self.csSwitch = [self addRow:@"dump.cs" desc:@"Full C# dump" y:y];
        y += 70;

        self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.dumpButton.frame = CGRectMake(16, y, w - 32, 46);
        self.dumpButton.backgroundColor = [ToolTheme shared].accent;
        [self.dumpButton setTitle:@"Generate Ghidra Dump" forState:UIControlStateNormal];
        [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.dumpButton addTarget:self action:@selector(startDump) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.dumpButton];
    }
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
    if (self.isDumping) return;
    self.isDumping = YES;
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            IL2CPPResolver *r = [IL2CPPResolver shared];
            if (!r || ![r resolve]) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool { ws.isDumping = NO; }
            });
        }
    });
}

- (void)reload { @autoreleasepool { self.isDumping = NO; } }

@end
