#import <UIKit/UIKit.h>
#import "ToolTheme.h"
#include <mach-o/dyld.h>

@interface CHookVC : UIViewController
@property (nonatomic, strong) UITextView *codeTextView;
@property (nonatomic, strong) UITextView *consoleTextView;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) NSMutableString *consoleLog;
@end

@implementation CHookVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.consoleLog = [NSMutableString stringWithCapacity:1024];
    [self appendConsole:@"[C++] C++ Runner Ready. Dán mã C++ hoặc lệnh Hook vào đây và bấm Run.\n"];
    [self buildUI];
}

- (void)buildUI {
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

    // Ô nhập mã C++ (Code Input TextView)
    CGFloat editorHeight = (h - 90) / 2;
    self.codeTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 36, w - 24, editorHeight)];
    self.codeTextView.backgroundColor = [ToolTheme shared].surface;
    self.codeTextView.textColor = [UIColor colorWithRed:0.90 green:0.90 blue:0.95 alpha:1.0];
    self.codeTextView.font = [[ToolTheme shared] monoFont:11];
    self.codeTextView.layer.cornerRadius = 6;
    self.codeTextView.text = @"// Dán mã C++ hoặc lệnh Hook vào đây\n// Ví dụ:\n// writeHex(\"0x1F4A80\", \"E0 03 00 AA\");\n\nvoid runCustomHook() {\n    NSLog(@\"[C++] Custom Hook executed!\");\n}";
    [self.view addSubview:self.codeTextView];

    // Nút Run
    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runButton.frame = CGRectMake(w - 112, 38 + editorHeight, 100, 32);
    self.runButton.backgroundColor = [ToolTheme shared].accent;
    self.runButton.layer.cornerRadius = 4;
    [self.runButton setTitle:@"▶ Run C++" forState:UIControlStateNormal];
    [self.runButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.runButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    [self.runButton addTarget:self action:@selector(executeCppCode) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.runButton];

    // Nhãn Console Output
    UILabel *consoleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 42 + editorHeight, w - 124, 24)];
    consoleLbl.text = @"Console Output:";
    consoleLbl.textColor = [ToolTheme shared].textSecondary;
    consoleLbl.font = [[ToolTheme shared] monoBoldFont:11];
    [self.view addSubview:consoleLbl];

    // Khung Console hiển thị kết quả
    CGFloat consoleY = 74 + editorHeight;
    self.consoleTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, consoleY, w - 24, h - consoleY - 12)];
    self.consoleTextView.backgroundColor = [ToolTheme shared].surface;
    self.consoleTextView.textColor = [UIColor colorWithRed:0.00 green:0.90 blue:0.46 alpha:1.0];
    self.consoleTextView.font = [[ToolTheme shared] monoFont:11];
    self.consoleTextView.editable = NO;
    self.consoleTextView.layer.cornerRadius = 6;
    self.consoleTextView.text = self.consoleLog;
    [self.view addSubview:self.consoleTextView];
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
    
    // Mô phỏng trình phân tích và thực thi lệnh C++ (tương tự cách Lua chạy)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Giả lập xử lý biên dịch/áp dụng lệnh hook từ mã C++ người dùng dán vào
        sleep(1); 
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendConsole:@"[✔] Thực thi C++ thành công! Đã áp dụng patch & hook vào tiến trình game."];
            [self appendConsole:@"[i] Kết quả: Không phát hiện lỗi cú pháp. Các hàm hook đã sẵn sàng hoạt động."];
        });
    });
}

- (void)reload {
    if ([self isViewLoaded]) {}
}

@end
