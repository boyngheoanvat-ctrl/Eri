#import "LuaVC.h"
#import "LuaEngine.h"
#import "ToolTheme.h"
#include <dlfcn.h>

@interface LuaVC () <UITextViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITextView *editorView;
@property (nonatomic, strong) UITextView *consoleView;
@property (nonatomic, strong) UIButton *runStopButton; // Dùng chung 1 nút duy nhất
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *pasteButton;

@property (nonatomic, strong) NSString *savedScriptContent;
@property (nonatomic, strong) NSString *savedConsoleText;
@property (nonatomic, assign) BOOL isScriptRunning;

// Cửa sổ ImGui Floating Menu con khi script chạy
@property (nonatomic, strong) UIView *imguiFloatingWindow;
@end

@implementation LuaVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    if (!self.savedScriptContent) {
        self.savedScriptContent = @"-- Lua Script with ImGui Menu\n"
                                  @"print(\"Eri Lua & ImGui Ready!\")\n"
                                  @"-- imgui.begin(\"Lua Mod Menu\")";
    }
    if (!self.savedConsoleText) {
        self.savedConsoleText = @"-- Lua Console --\n";
    }
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.contentSize = CGSizeMake(w, h + 50);
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    CGFloat pad = 8;
    CGFloat y = 8;
    
    // Chia 3 nút hàng đầu: Run/Stop (chiếm nửa), Paste, Clear
    CGFloat availableW = w - (pad * 4);
    CGFloat runBtnW = availableW * 0.4;
    CGFloat otherBtnW = (availableW * 0.6) / 2.0;
    CGFloat btnH = 36;

    // Nút Run/Stop dùng chung duy nhất
    self.runStopButton = [self makeButton:@"▶️ Chạy" x:pad y:y w:runBtnW h:btnH color:[UIColor colorWithRed:0.20 green:0.70 blue:0.40 alpha:1.0]];
    [self.runStopButton addTarget:self action:@selector(runStopTapped) forControlEvents:UIControlEventTouchUpInside];

    self.pasteButton = [self makeButton:@"Paste" x:pad * 2 + runBtnW y:y w:otherBtnW h:btnH color:[UIColor colorWithRed:0.30 green:0.50 blue:0.70 alpha:1.0]];
    [self.pasteButton addTarget:self action:@selector(pasteTapped) forControlEvents:UIControlEventTouchUpInside];

    self.clearButton = [self makeButton:@"Clear" x:pad * 3 + runBtnW + otherBtnW y:y w:otherBtnW h:btnH color:[UIColor colorWithRed:0.40 green:0.40 blue:0.40 alpha:1.0]];
    [self.clearButton addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];

    y += btnH + 8;

    UILabel *editorLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 16)];
    editorLabel.text = @"EDITOR (LUA & IMGUI SCRIPT)";
    editorLabel.textColor = [ToolTheme shared].textMuted;
    editorLabel.font = [[ToolTheme shared] monoFont:10];
    editorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:editorLabel];
    y += 20;

    CGFloat editorH = 180;
    self.editorView = [[UITextView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, editorH)];
    self.editorView.backgroundColor = [ToolTheme shared].surface;
    self.editorView.textColor = [ToolTheme shared].textPrimary;
    self.editorView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.editorView.layer.cornerRadius = 4;
    self.editorView.text = self.savedScriptContent;
    self.editorView.delegate = self;
    self.editorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.editorView];
    y += editorH + 8;

    UILabel *consoleLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 16)];
    consoleLabel.text = @"CONSOLE OUTPUT";
    consoleLabel.textColor = [ToolTheme shared].textMuted;
    consoleLabel.font = [[ToolTheme shared] monoFont:10];
    consoleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:consoleLabel];
    y += 20;

    CGFloat consoleH = MAX(120, h - y - pad - 40);
    self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, consoleH)];
    self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    self.consoleView.textColor = [ToolTheme shared].success;
    self.consoleView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.consoleView.editable = NO;
    self.consoleView.layer.cornerRadius = 4;
    self.consoleView.text = self.savedConsoleText;
    self.consoleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scrollView addSubview:self.consoleView];
}

- (UIButton *)makeButton:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h color:(UIColor *)color {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, h);
    b.backgroundColor = color;
    b.layer.cornerRadius = 4;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    b.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    [self.scrollView addSubview:b];
    return b;
}

#pragma mark - Toggle Run / Stop Button Handler

- (void)runStopTapped {
    if (!self.isScriptRunning) {
        // Trạng thái chuẩn bị chạy -> Chuyển nút thành ĐỎ [🟥 Dừng]
        self.isScriptRunning = YES;
        [self.runStopButton setTitle:@"🟥 Dừng" forState:UIControlStateNormal];
        self.runStopButton.backgroundColor = [UIColor colorWithRed:0.80 green:0.20 blue:0.20 alpha:1.0];
        
        NSString *script = self.editorView.text;
        if (script.length == 0) return;

        [self.editorView resignFirstResponder];
        [self log:@"[Lua] Đang thực thi script & khởi tạo ImGui Menu..."];

        // Hiển thị ImGui Floating Menu đè lên màn hình game
        [self showImGuiFloatingMenu];

        __weak typeof(self) ws = self;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *result = [[LuaEngine shared] runScript:script];
            dispatch_async(dispatch_get_main_queue(), ^{
                [ws log:result];
            });
        });
    } else {
        // Đang chạy mà bấm vào -> Thực hiện DỪNG -> Chuyển nút về XANH [▶️ Chạy]
        [self stopScriptExecution];
    }
}

- (void)stopScriptExecution {
    self.isScriptRunning = NO;
    [[LuaEngine shared] stop];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.runStopButton setTitle:@"▶️ Chạy" forState:UIControlStateNormal];
        self.runStopButton.backgroundColor = [UIColor colorWithRed:0.20 green:0.70 blue:0.40 alpha:1.0];
        [self log:@"[Lua] Đã dừng script & ẩn ImGui Menu."];
        [self hideImGuiFloatingMenu];
    });
}

#pragma mark - ImGui Floating Menu (Menu nổi y như menu mod)

- (void)showImGuiFloatingMenu {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    if (!keyWindow) return;

    if (self.imguiFloatingWindow) {
        [self.imguiFloatingWindow removeFromSuperview];
    }

    // Tạo cửa sổ ImGui Menu nổi trên màn hình game (có thể kéo thả / tuỳ chỉnh)
    CGFloat menuW = 260;
    CGFloat menuH = 220;
    CGFloat screenW = CGRectGetWidth(keyWindow.bounds);
    CGFloat screenH = CGRectGetHeight(keyWindow.bounds);
    
    self.imguiFloatingWindow = [[UIView alloc] initWithFrame:CGRectMake((screenW - menuW) / 2, (screenH - menuH) / 2, menuW, menuH)];
    self.imguiFloatingWindow.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:0.92];
    self.imguiFloatingWindow.layer.cornerRadius = 8;
    self.imguiFloatingWindow.layer.borderWidth = 1.5;
    self.imguiFloatingWindow.layer.borderColor = [ToolTheme shared].accent.CGColor;

    // Tiêu đề ImGui Menu
    UILabel *headerLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, menuW - 40, 24)];
    headerLbl.text = @"⚙️ ImGui Lua Mod Menu";
    headerLbl.textColor = [ToolTheme shared].textPrimary;
    headerLbl.font = [[ToolTheme shared] monoBoldFont:12];
    [self.imguiFloatingWindow addSubview:headerLbl];

    // Nút đóng menu nổi
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(menuW - 32, 8, 24, 24);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(stopScriptExecution) forControlEvents:UIControlEventTouchUpInside];
    [self.imguiFloatingWindow addSubview:closeBtn];

    // Thêm các tính năng giả lập trong ImGui Menu (Toggle switches)
    NSArray *features = @[@"Bật Sáng Bản Đồ (Hack Map)", @"Bật Khoảng Cách (ESP)", @"Mod Skin Tướng", @"Bất Tử (God Mode)"];
    CGFloat fy = 38;
    for (int i = 0; i < features.count; i++) {
        UILabel *fLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, fy, menuW - 70, 28)];
        fLbl.text = features[i];
        fLbl.textColor = [ToolTheme shared].textPrimary;
        fLbl.font = [[ToolTheme shared] monoFont:10];
        [self.imguiFloatingWindow addSubview:fLbl];

        UISwitch *fSw = [[UISwitch alloc] initWithFrame:CGRectMake(menuW - 60, fy - 2, 40, 24)];
        fSw.onTintColor = [ToolTheme shared].accent;
        [fSw addTarget:self action:@selector(imguiSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.imguiFloatingWindow addSubview:fSw];

        fy += 34;
    }

    [keyWindow addSubview:self.imguiFloatingWindow];
}

- (void)hideImGuiFloatingMenu {
    if (self.imguiFloatingWindow) {
        [self.imguiFloatingWindow removeFromSuperview];
        self.imguiFloatingWindow = nil;
    }
}

- (void)imguiSwitchChanged:(UISwitch *)sender {
    [self log:[NSString stringWithFormat:@"[ImGui] Tính năng trạng thái: %@", sender.isOn ? @"ON" : @"OFF"]];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    if (textView == self.editorView) {
        self.savedScriptContent = textView.text;
    }
}

#pragma mark - Actions

- (void)pasteTapped {
    NSString *clip = [UIPasteboard generalPasteboard].string;
    if (clip.length > 0) {
        self.editorView.text = clip;
        self.savedScriptContent = clip;
        [self log:@"[Lua] Pasted from clipboard"];
    }
}

- (void)clearTapped {
    self.savedConsoleText = @"-- Lua Console --\n";
    self.consoleView.text = self.savedConsoleText;
}

- (void)setScriptContent:(NSString *)content {
    if (content && content.length > 0) {
        self.savedScriptContent = content;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.editorView) self.editorView.text = content;
            [self log:@"[Lua AI] Đã nhận script mới từ AI Chat!"];
        });
    }
}

- (void)log:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *current = self.consoleView.text ?: @"-- Lua Console --\n";
        self.savedConsoleText = [current stringByAppendingFormat:@"%@\n", text];
        self.consoleView.text = self.savedConsoleText;
        [self.consoleView scrollRangeToVisible:NSMakeRange(self.consoleView.text.length - 1, 1)];
    });
}

- (void)reload {
    if (self.editorView && self.savedScriptContent) self.editorView.text = self.savedScriptContent;
    if (self.consoleView && self.savedConsoleText) self.consoleView.text = self.savedConsoleText;
}

@end
