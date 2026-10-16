#import "LuaVC.h"
#import "LuaEngine.h"
#import "ToolTheme.h"
#include <dlfcn.h>

@interface ImGuiWindow : UIWindow
@end

@implementation ImGuiWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [super pointInside:point withEvent:event];
}
@end

@interface LuaVC () <UITextViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITextView *editorView;
@property (nonatomic, strong) UITextView *consoleView;
@property (nonatomic, strong) UIButton *runStopButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *pasteButton;

@property (nonatomic, strong) NSString *savedScriptContent;
@property (nonatomic, strong) NSString *savedConsoleText;
@property (nonatomic, assign) BOOL isScriptRunning;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *activeModules;
@end

// Chuyển các biến static ra ngoài @interface
static ImGuiWindow *sharedImGuiWindow = nil;
static UIView *sharedImGuiContainerView = nil;

@implementation LuaVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    if (!self.savedScriptContent) {
        self.savedScriptContent = @"-- Lua Script with ImGui Menu\nprint(\"Eri Lua & ImGui Ready!\")";
    }
    if (!self.savedConsoleText) {
        self.savedConsoleText = @"-- Lua Console --\n";
    }
    if (!self.activeModules) {
        self.activeModules = [NSMutableArray array];
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
    CGFloat availableW = w - (pad * 4);
    CGFloat runBtnW = availableW * 0.4;
    CGFloat otherBtnW = (availableW * 0.6) / 2.0;
    CGFloat btnH = 36;

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

- (void)setActiveModules:(NSMutableArray<NSDictionary *> *)modules {
    if (modules) {
        self.activeModules = modules;
    }
}

- (void)runStopTapped {
    if (!self.isScriptRunning) {
        self.isScriptRunning = YES;
        [self.runStopButton setTitle:@"🟥 Dừng" forState:UIControlStateNormal];
        self.runStopButton.backgroundColor = [UIColor colorWithRed:0.80 green:0.20 blue:0.20 alpha:1.0];
        
        NSString *script = self.editorView.text;
        if (script.length == 0) return;

        [self.editorView resignFirstResponder];
        [self log:@"[Lua] Đang chạy script & hiển thị ImGui Menu..."];

        [self showIndependentImGuiMenu];

        __weak typeof(self) ws = self;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *result = [[LuaEngine shared] runScript:script];
            dispatch_async(dispatch_get_main_queue(), ^{
                [ws log:result];
            });
        });
    } else {
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
        [self hideIndependentImGuiMenu];
    });
}

#pragma mark - ImGui Floating Menu Độc Lập

- (void)showIndependentImGuiMenu {
    if (sharedImGuiWindow) {
        [self hideIndependentImGuiMenu];
    }

    UIScreen *screen = [UIScreen mainScreen];
    sharedImGuiWindow = [[ImGuiWindow alloc] initWithFrame:screen.bounds];
    sharedImGuiWindow.windowLevel = UIWindowLevelAlert + 999;
    sharedImGuiWindow.backgroundColor = [UIColor clearColor];
    
    UIViewController *emptyVC = [[UIViewController alloc] init];
    emptyVC.view.backgroundColor = [UIColor clearColor];
    sharedImGuiWindow.rootViewController = emptyVC;
    
    CGFloat menuW = 280;
    CGFloat headerH = 36;
    CGFloat rowH = 34;
    
    NSUInteger count = self.activeModules.count > 0 ? self.activeModules.count : 1;
    CGFloat menuH = headerH + (count * rowH) + 12;
    
    CGFloat screenW = CGRectGetWidth(screen.bounds);
    CGFloat screenH = CGRectGetHeight(screen.bounds);
    
    sharedImGuiContainerView = [[UIView alloc] initWithFrame:CGRectMake((screenW - menuW) / 2, (screenH - menuH) / 2, menuW, menuH)];
    sharedImGuiContainerView.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:0.95];
    sharedImGuiContainerView.layer.cornerRadius = 8;
    sharedImGuiContainerView.layer.borderWidth = 1.5;
    sharedImGuiContainerView.layer.borderColor = [ToolTheme shared].accent.CGColor;

    UILabel *headerLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, menuW - 40, 24)];
    headerLbl.text = @"⚙️ ImGui Mod Menu";
    headerLbl.textColor = [ToolTheme shared].textPrimary;
    headerLbl.font = [[ToolTheme shared] monoBoldFont:11];
    [sharedImGuiContainerView addSubview:headerLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(menuW - 30, 6, 24, 24);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(stopScriptExecution) forControlEvents:UIControlEventTouchUpInside];
    [sharedImGuiContainerView addSubview:closeBtn];

    CGFloat fy = headerH;
    
    if (self.activeModules.count == 0) {
        UILabel *fLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, fy, menuW - 75, 28)];
        fLbl.text = @"Bật Sáng Bản Đồ (Hack Map)";
        fLbl.textColor = [ToolTheme shared].textPrimary;
        fLbl.font = [[ToolTheme shared] monoFont:10];
        [sharedImGuiContainerView addSubview:fLbl];

        UISwitch *fSw = [[UISwitch alloc] initWithFrame:CGRectMake(menuW - 65, fy + 2, 40, 24)];
        fSw.onTintColor = [ToolTheme shared].accent;
        [fSw addTarget:self action:@selector(imguiSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [sharedImGuiContainerView addSubview:fSw];
    } else {
        for (NSDictionary *mod in self.activeModules) {
            UILabel *fLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, fy, menuW - 75, 28)];
            fLbl.text = mod[@"title"] ?: @"Tính năng Mod";
            fLbl.textColor = [ToolTheme shared].textPrimary;
            fLbl.font = [[ToolTheme shared] monoFont:10];
            [sharedImGuiContainerView addSubview:fLbl];

            UISwitch *fSw = [[UISwitch alloc] initWithFrame:CGRectMake(menuW - 65, fy + 2, 40, 24)];
            fSw.onTintColor = [ToolTheme shared].accent;
            [fSw addTarget:self action:@selector(imguiSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            [sharedImGuiContainerView addSubview:fSw];

            fy += rowH;
        }
    }

    [emptyVC.view addSubview:sharedImGuiContainerView];
    sharedImGuiWindow.hidden = NO;
}

- (void)hideIndependentImGuiMenu {
    if (sharedImGuiWindow) {
        sharedImGuiWindow.hidden = YES;
        sharedImGuiWindow.rootViewController = nil;
        sharedImGuiWindow = nil;
        sharedImGuiContainerView = nil;
    }
}

- (void)imguiSwitchChanged:(UISwitch *)sender {
    [self log:[NSString stringWithFormat:@"[ImGui Mod] Trạng thái: %@", sender.isOn ? @"ON" : @"OFF"]];
}

- (void)textViewDidChange:(UITextView *)textView {
    if (textView == self.editorView) {
        self.savedScriptContent = textView.text;
    }
}

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
