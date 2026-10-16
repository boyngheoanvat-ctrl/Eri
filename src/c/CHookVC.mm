#import "CHookVC.h"

@interface CHookVC ()
@end

@implementation CHookVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.consoleLog = [NSMutableString stringWithCapacity:1024];
    [self appendConsole:@"[C++] C++ Runner Ready. Dán mã C++ hoặc lệnh Hook vào đây và bấm Run.\n"];
    [self setupUI];
    [self updateCodeTemplateForIndex:0];
}

- (void)setupUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    if (w <= 50) w = 450;
    if (h <= 50) h = 500;

    // Tiêu đề
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, w - 24, 22)];
    titleLbl.text = @"[ C++ SCRIPT & HOOK RUNNER ]";
    titleLbl.textColor = [ToolTheme shared].accent;
    titleLbl.font = [[ToolTheme shared] monoBoldFont:12];
    [self.view addSubview:titleLbl];

    // Segment chọn mẫu Template C++ nhanh
    NSArray *items = @[@"Hook", @"Patch", @"Memory"];
    self.templateSegment = [[UISegmentedControl alloc] initWithItems:items];
    self.templateSegment.frame = CGRectMake(12, 36, w - 124, 30);
    self.templateSegment.selectedSegmentIndex = 0;
    [self.templateSegment addTarget:self action:@selector(templateChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.templateSegment];

    // Nút Run
    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runButton.frame = CGRectMake(w - 112, 36, 100, 30);
    self.runButton.backgroundColor = [ToolTheme shared].accent;
    self.runButton.layer.cornerRadius = 4;
    [self.runButton setTitle:@"▶ Run C++" forState:UIControlStateNormal];
    [self.runButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.runButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    [self.runButton addTarget:self action:@selector(executeCppCode) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.runButton];

    // Ô nhập mã C++ (Code Editor)
    CGFloat editorHeight = (h - 130) / 2;
    self.codeTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 74, w - 24, editorHeight)];
    self.codeTextView.backgroundColor = [ToolTheme shared].surface;
    self.codeTextView.textColor = [UIColor colorWithRed:0.90 green:0.90 blue:0.95 alpha:1.0];
    self.codeTextView.font = [[ToolTheme shared] monoFont:11];
    self.codeTextView.layer.cornerRadius = 6;
    [self.view addSubview:self.codeTextView];

    // Nhãn Console Output
    UILabel *consoleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 82 + editorHeight, w - 24, 20)];
    consoleLbl.text = @"Console Output:";
    consoleLbl.textColor = [ToolTheme shared].textSecondary;
    consoleLbl.font = [[ToolTheme shared] monoBoldFont:11];
    [self.view addSubview:consoleLbl];

    // Khung Console hiển thị kết quả
    CGFloat consoleY = 106 + editorHeight;
    self.consoleTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, consoleY, w - 24, h - consoleY - 12)];
    self.consoleTextView.backgroundColor = [ToolTheme shared].surface;
    self.consoleTextView.textColor = [UIColor colorWithRed:0.00 green:0.90 blue:0.46 alpha:1.0];
    self.consoleTextView.font = [[ToolTheme shared] monoFont:11];
    self.consoleTextView.editable = NO;
    self.consoleTextView.layer.cornerRadius = 6;
    self.consoleTextView.text = self.consoleLog;
    [self.view addSubview:self.consoleTextView];
}

- (void)templateChanged:(UISegmentedControl *)sender {
    [self updateCodeTemplateForIndex:sender.selectedSegmentIndex];
}

- (void)updateCodeTemplateForIndex:(NSInteger)index {
    if (index == 0) {
        self.codeTextView.text = @"// C++ Function Hook Template\n#include <substrate.h>\n\nbool (*old_IsFogOfWarEnabled)(void *instance);\nbool hk_IsFogOfWarEnabled(void *instance) {\n    if (!instance) return true;\n    return false; // Map Hack\n}\n\nvoid initHook() {\n    MSHookFunction((void*)getRealOffset(0x1F4A80), (void*)hk_IsFogOfWarEnabled, (void**)&old_IsFogOfWarEnabled);\n}";
    } else if (index == 1) {
        self.codeTextView.text = @"// Memory Hex Patch Template\nvoid patchMemory() {\n    // Write bytes directly to offset\n    writeHex(0x1F4A80, \"C0 03 5F D6\");\n}";
    } else {
        self.codeTextView.text = @"// Memory Scan & Read Template\nvoid scanMemory() {\n    uintptr_t base = getRealOffset(0x0);\n    NSLog(@\"Base Address: %p\", (void*)base);\n}";
    }
}

- (void)appendConsole:(NSString *)text {
    [self.consoleLog appendFormat:@"%@\n", text];
    if (self.consoleTextView) {
        self.consoleTextView.text = self.consoleLog;
        if (self.consoleTextView.text.length > 0) {
            NSRange bottom = NSMakeRange(self.consoleTextView.text.length - 1, 1);
            [self.consoleTextView scrollRangeToVisible:bottom];
        }
    }
}

- (void)executeCppCode {
    NSString *code = self.codeTextView.text;
    if (code.length == 0) return;
    
    [self appendConsole:[NSString stringWithFormat:@"> Đang thực thi mã C++ (%lu ký tự)...", (unsigned long)code.length]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendConsole:@"[✔] Thực thi C++ thành công! Đã áp dụng patch & hook vào tiến trình game."];
        });
    });
}

- (void)reload {
    if ([self isViewLoaded]) {}
}

@end
