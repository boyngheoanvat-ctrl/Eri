#import "CHookVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@interface CHookVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *rvaField;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UIButton *patchButton;
@property (nonatomic, strong) UITextView *consoleView;
@end

@implementation CHookVC

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
        title.text = @"C++ Hook & Ghidra Patch Suite";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 36;

        self.rvaField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
        self.rvaField.placeholder = @"Nhập Ghidra RVA (vd: 0x1073083C0)...";
        self.rvaField.backgroundColor = [ToolTheme shared].surface;
        self.rvaField.textColor = [ToolTheme shared].textPrimary;
        self.rvaField.font = [[ToolTheme shared] monoFont:12];
        self.rvaField.layer.cornerRadius = 6;
        self.rvaField.delegate = self;
        [self.view addSubview:self.rvaField];
        y += 50;

        self.valueField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
        self.valueField.placeholder = @"Nhập giá trị Patch (vd: 9999)...";
        self.valueField.backgroundColor = [ToolTheme shared].surface;
        self.valueField.textColor = [ToolTheme shared].textPrimary;
        self.valueField.font = [[ToolTheme shared] monoFont:12];
        self.valueField.layer.cornerRadius = 6;
        self.valueField.delegate = self;
        [self.view addSubview:self.valueField];
        y += 50;

        self.patchButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.patchButton.frame = CGRectMake(16, y, w - 32, 46);
        self.patchButton.backgroundColor = [ToolTheme shared].accent;
        [self.patchButton setTitle:@"Thực thi Patch RVA" forState:UIControlStateNormal];
        [self.patchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.patchButton addTarget:self action:@selector(didTapPatch) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.patchButton];
        y += 58;

        self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, 150)];
        self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
        self.consoleView.textColor = [ToolTheme shared].success;
        self.consoleView.font = [[ToolTheme shared] monoFont:10];
        self.consoleView.editable = NO;
        self.consoleView.layer.cornerRadius = 6;
        self.consoleView.text = @"-- C++ Hook Console Ready --";
        [self.view addSubview:self.consoleView];
    }
}

- (void)didTapPatch {
    @autoreleasepool {
        unsigned long long rvaVal = strtoull(self.rvaField.text.UTF8String, NULL, 16);
        uintptr_t absoluteAddr = [IL2CPPResolver getRealOffset:(uintptr_t)rvaVal];
        float floatVal = self.valueField.text.floatValue;
        BOOL success = [IL2CPPResolver writeFloat:absoluteAddr value:floatVal];
        self.consoleView.text = [NSString stringWithFormat:@"[CHook] Patch RVA: %@ -> Addr: %p\nTrạng thái: %@", self.rvaField.text, (void*)absoluteAddr, success ? @"THÀNH CÔNG" : @"THẤT BẠI"];
    }
}

- (void)reload {}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }

@end
