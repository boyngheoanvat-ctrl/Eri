#import "AIChatVC.h"
#import "ToolTheme.h"
#import "AICHookGenerator.h"

@interface AIChatVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextView *chatTextView;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSMutableString *chatLog;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.chatLog = [NSMutableString stringWithCapacity:1024];
    [self appendLog:@"[ai] 🤖 AI Agent ready.\n- Hoi: hack map, unlock skin, speed, god mode...\n"];
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    if (w <= 50) w = 450;
    if (h <= 50) h = 500;

    // Chiều cao cố định cho thanh nhập liệu ở đáy
    CGFloat bottomBarHeight = 60;

    // Vùng hiển thị nội dung chat (Đã trừ chiều cao thanh đáy để không bao giờ bị che)
    self.chatTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 12, w - 24, h - bottomBarHeight - 24)];
    self.chatTextView.backgroundColor = [ToolTheme shared].surface;
    self.chatTextView.textColor = [ToolTheme shared].textPrimary;
    self.chatTextView.font = [[ToolTheme shared] monoFont:12];
    self.chatTextView.editable = NO;
    self.chatTextView.layer.cornerRadius = 6;
    self.chatTextView.text = self.chatLog;
    
    // Tạo khoảng đệm bên trong để chữ không bị sát mép
    UIEdgeInsets insets = UIEdgeInsetsMake(8, 8, 16, 8);
    self.chatTextView.textContainerInset = insets;
    
    [self.view addSubview:self.chatTextView];

    // Thanh chứa khung nhập tin nhắn nằm cố định gọn gàng ở đáy
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(12, h - bottomBarHeight - 8, w - 24, 50)];
    bottomBar.backgroundColor = [ToolTheme shared].surface;
    bottomBar.layer.cornerRadius = 6;
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:bottomBar];

    // Ô nhập văn bản (TextField)
    self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(10, 5, bottomBar.bounds.size.width - 84, 40)];
    self.inputField.placeholder = @"input here...";
    self.inputField.textColor = [ToolTheme shared].textPrimary;
    self.inputField.font = [[ToolTheme shared] monoFont:12];
    self.inputField.delegate = self;
    self.inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [bottomBar addSubview:self.inputField];

    // Nút Gửi (Send Button)
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(bottomBar.bounds.size.width - 70, 8, 62, 34);
    self.sendButton.backgroundColor = [ToolTheme shared].accent;
    self.sendButton.layer.cornerRadius = 4;
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    [self.sendButton addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [bottomBar addSubview:self.sendButton];
}

- (void)appendLog:(NSString *)text {
    [self.chatLog appendFormat:@"%@\n", text];
    if (self.chatTextView) {
        self.chatTextView.text = self.chatLog;
        // Tự động cuộn xuống dòng mới nhất khi có tin nhắn/kết quả mới
        if (self.chatTextView.text.length > 0) {
            NSRange bottom = NSMakeRange(self.chatTextView.text.length - 1, 1);
            [self.chatTextView scrollRangeToVisible:bottom];
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage];
    return YES;
}

- (void)sendMessage {
    NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;

    [self appendLog:[NSString stringWithFormat:@"> %@", text]];
    self.inputField.text = @"";
    [self.inputField resignFirstResponder];

    // Xử lý yêu cầu từ người dùng
    if ([text.lowercaseString containsString:@"hack map"] || [text.lowercaseString containsString:@"zoom"]) {
        [self appendLog:@"[ai] 🎯 Đang phân tích và generate Map Hack..."];
        [[AICHookGenerator shared] generateMapHackForQuery:text completion:^(AICHookGeneratorResult *result) {
            [self appendLog:[NSString stringWithFormat:@"[ai] 🎯 [AI Map Hack Generator Found]\n- Target Offset: %@\n\n=== C++ HOOK CODE ===\n%@", result.offsetAddress, result.cppCode]];
        }];
    } else {
        [self appendLog:[NSString stringWithFormat:@"[ai] 🤖 Chào bạn! Tôi đã ghi nhận yêu cầu: \"%@\"", text]];
    }
}

- (void)reload {
    if ([self isViewLoaded]) {
        self.chatTextView.text = self.chatLog;
    }
}

@end
