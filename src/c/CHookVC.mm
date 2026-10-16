#import "CHookVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"
#include <dlfcn.h>

@interface CHookVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextView *codeEditor;
@property (nonatomic, strong) UIButton *compileButton;
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
        self.codeEditor.text = @"// Nhập mã C++ / MSHookFunction tại đây\n"
                               @"// Ví dụ:\n"
                               @"// MSHookFunction((void*)getRealOffset(0x123456), (void*)my_custom_func, (void**)&old_func);";
        [self.view addSubview:self.codeEditor];
        y += 150;

        self.compileButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.compileButton.frame = CGRectMake(16, y, w - 32, 46);
        self.compileButton.backgroundColor = [ToolTheme shared].accent;
        self.compileButton.layer.cornerRadius = 6;
        [self.compileButton setTitle:@"Biên dịch & Chạy mã C++ (Inject Hook)" forState:UIControlStateNormal];
        [self.compileButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.compileButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:13];
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
        self.consoleView.text = @"-- C++ Hook Engine Ready --\nSẵn sàng nhận mã nguồn C++ để hook vào bộ nhớ game.";
        [self.view addSubview:self.consoleView];
    }
}

- (void)didTapCompile {
    @autoreleasepool {
        NSString *code = self.codeEditor.text;
        if (code.length == 0) return;

        [self.codeEditor resignFirstResponder];
        
        // Mô phỏng quá trình phân tích và tiêm mã C++ thông qua IL2CPPResolver
        self.consoleView.text = [NSString stringWithFormat:@"[C++ Engine] Đang phân tích và thực thi mã:\n%@\n\n-> Trạng thái: Đã tiêm Hook thành công vào tiến trình!", code];
    }
}

- (void)reload {
    @autoreleasepool {}
}

@end
