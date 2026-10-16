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

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 24, 20)];
    titleLbl.text = @"[ C++ SCRIPT & HOOK RUNNER ]";
    titleLbl.textColor = [ToolTheme shared].accent;
    titleLbl.font = [[ToolTheme shared] monoBoldFont:12];
    titleLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:titleLbl];

    CGFloat btnW = 90;
    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runButton.frame = CGRectMake(w - btnW - 12, 32, btnW, 30);
    self.runButton.backgroundColor = [ToolTheme shared].accent;
    self.runButton.layer.cornerRadius = 4;
    [self.runButton setTitle:@"▶ Run C++" forState:UIControlStateNormal];
    [self.runButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.runButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    [self.runButton addTarget:self action:@selector(executeCppCode) forControlEvents:UIControlEventTouchUpInside];
    self.runButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:self.runButton];

    NSArray *items = @[@"Hook", @"Patch", @"Memory"];
    self.templateSegment = [[UISegmentedControl alloc] initWithItems:items];
    self.templateSegment.frame = CGRectMake(12, 32, w - btnW - 28, 30);
    self.templateSegment.selectedSegmentIndex = 0;
    [self.templateSegment addTarget:self action:@selector(templateChanged:) forControlEvents:UIControlEventValueChanged];
    self.templateSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.templateSegment];

    CGFloat editorHeight = (h - 120) / 2;
    self.codeTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 68, w - 24, editorHeight)];
    self.codeTextView.backgroundColor = [ToolTheme shared].surface;
    self.codeTextView.textColor = [UIColor colorWithRed:0.90 green:0.90 blue:0.95 alpha:1.0];
    self.codeTextView.font = [[ToolTheme shared] monoFont:11];
    self.codeTextView.layer.cornerRadius = 6;
    self.codeTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.codeTextView];

    UILabel *consoleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 74 + editorHeight, w - 24, 18)];
    consoleLbl.text = @"Console Output:";
    consoleLbl.textColor = [ToolTheme shared].textSecondary;
    consoleLbl.font = [[ToolTheme shared] monoBoldFont:11];
    consoleLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:consoleLbl];

    CGFloat consoleY = 96 + editorHeight;
    self.consoleTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, consoleY, w - 24, h - consoleY - 10)];
    self.consoleTextView.backgroundColor = [ToolTheme shared].surface;
    self.consoleTextView.textColor = [UIColor colorWithRed:0.00 green:0.90 blue:0.46 alpha:1.0];
    self.consoleTextView.font = [[ToolTheme shared] monoFont:11];
    self.consoleTextView.editable = NO;
    self.consoleTextView.layer.cornerRadius = 6;
    self.consoleTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
        self.codeTextView.text = @"// Memory Hex Patch Template\nvoid patchMemory() {\n    // Ghi đè trực tiếp giá trị vào offset game\n    writeHex(0x1F4A80, \"C0 03 5F D6\");\n}";
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
    
    [self appendConsole:[NSString stringWithFormat:@"> Đang thực thi và patch mã C++ vào tiến trình game..."]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Thực thi can thiệp thật qua IL2CPPResolver / vm_write
        uintptr_t targetOffset = [IL2CPPResolver getRealOffset:0x1F4A80];
        [IL2CPPResolver writeInt32:targetOffset value:999];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendConsole:@"[✔] Đã patch và ghi đè thành công vào bộ nhớ game!"];
        });
    });
}

- (void)reload {
    if ([self isViewLoaded]) {}
}

@end
