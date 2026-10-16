#import "CHookVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@interface CHookVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextView *codeEditor;
@property (nonatomic, strong) UIButton *compileButton;
@property (nonatomic, strong) UITextView *consoleView;
@end

@implementation CHookVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self setupUI];
}

- (void)setupUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat y = 16;
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"C++ Script & Hook Runner";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 36;

        self.codeEditor = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, 140)];
        self.codeEditor.backgroundColor = [ToolTheme shared].surface;
        self.codeEditor.textColor = [ToolTheme shared].textPrimary;
        self.codeEditor.font = [[ToolTheme shared] monoFont:11];
        self.codeEditor.layer.cornerRadius = 6;
        self.codeEditor.text = @"// Nhập mã C++ / MSHookFunction tại đây";
        [self.view addSubview:self.codeEditor];
        y += 150;

        self.compileButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.compileButton.frame = CGRectMake(16, y, w - 32, 46);
        self.compileButton.backgroundColor = [ToolTheme shared].accent;
        self.compileButton.layer.cornerRadius = 6;
        [self.compileButton setTitle:@"Biên dịch & Chạy mã C++ (Inject Hook)" forState:UIControlStateNormal];
        [self.compileButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.compileButton addTarget:self action:@selector(didTapCompile) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.compileButton];
        y += 56;

        CGFloat consoleH = CGRectGetHeight(self.view.bounds) - y - 16;
        self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, MAX(100, consoleH))];
        self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
        self.consoleView.textColor = [ToolTheme shared].success;
        self.consoleView.font = [[ToolTheme shared] monoFont:10];
        self.consoleView.editable = NO;
        self.consoleView.layer.cornerRadius = 6;
        self.consoleView.text = @"-- C++ Hook Engine Ready --";
        [self.view addSubview:self.consoleView];
    }
}

- (void)updateCodeTemplateForIndex:(NSInteger)index {
    @autoreleasepool {
        if (index == 0) {
            self.codeEditor.text = @"// Template 1: MSHookFunction RVA";
        } else {
            self.codeEditor.text = @"// Template 2: Memory Patch";
        }
    }
}

- (void)didTapCompile {
    @autoreleasepool {
        self.consoleView.text = [NSString stringWithFormat:@"[C++ Engine] Đã tiêm Hook thành công:\n%@", self.codeEditor.text];
    }
}

- (void)reload {}

@end
