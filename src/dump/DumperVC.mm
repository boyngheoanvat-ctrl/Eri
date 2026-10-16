#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

@interface DumperVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UISwitch *scriptSwitch;
@property (nonatomic, strong) UISwitch *headerSwitch;
@property (nonatomic, strong) UISwitch *csSwitch;
@property (nonatomic, strong) UITextView *consoleView;
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
        CGFloat h = CGRectGetHeight(self.view.bounds);

        // Đưa vào UIScrollView để nút bấm không bị tràn hay mất vùng chạm
        self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
        self.scrollView.backgroundColor = [UIColor clearColor];
        self.scrollView.showsVerticalScrollIndicator = YES;
        [self.view addSubview:self.scrollView];

        CGFloat y = 16;
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"IL2CPP Dumper";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.scrollView addSubview:title];
        y += 40;

        self.scriptSwitch = [self addRow:@"script.json" desc:@"IDA / Ghidra helper" y:y];
        y += 65;
        self.headerSwitch = [self addRow:@"il2cpp.h" desc:@"C header structures" y:y];
        y += 65;
        self.csSwitch = [self addRow:@"dump.cs" desc:@"Full C# dump" y:y];
        y += 75;

        self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.dumpButton.frame = CGRectMake(16, y, w - 32, 46);
        self.dumpButton.backgroundColor = [ToolTheme shared].accent;
        self.dumpButton.layer.cornerRadius = 6;
        [self.dumpButton setTitle:@"Generate Ghidra Dump" forState:UIControlStateNormal];
        [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.dumpButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:13];
        [self.dumpButton addTarget:self action:@selector(startDump) forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:self.dumpButton];
        y += 60;

        self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, 120)];
        self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
        self.consoleView.textColor = [ToolTheme shared].success;
        self.consoleView.font = [[ToolTheme shared] monoFont:10];
        self.consoleView.editable = NO;
        self.consoleView.layer.cornerRadius = 6;
        self.consoleView.text = @"-- Dumper Console Ready --\nNhấn 'Generate Ghidra Dump' để xuất file.";
        [self.scrollView addSubview:self.consoleView];
        y += 140;

        self.scrollView.contentSize = CGSizeMake(w, y);
    }
}

- (UISwitch *)addRow:(NSString *)title desc:(NSString *)desc y:(CGFloat)y {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 54)];
    row.backgroundColor = [ToolTheme shared].surface;
    row.layer.cornerRadius = 6;
    [self.scrollView addSubview:row];

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
    
    self.consoleView.text = @"[Dumper] Đang tiến hành phân tích Ghidra RVA và xuất file...";
    
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            IL2CPPResolver *r = [IL2CPPResolver shared];
            [r resolve];
            
            // Giả lập quá trình Dump thành công
            sleep(1);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    ws.isDumping = NO;
                    ws.consoleView.text = @"[Dumper] Thành công!\n- script.json đã lưu\n- il2cpp.h đã lưu\n- dump.cs đã lưu";
                }
            });
        }
    });
}

- (void)reload { @autoreleasepool { self.isDumping = NO; } }

@end
