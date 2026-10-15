#import "LuaVC.h"
#import "LuaEngine.h"
#import "ToolTheme.h"

@interface LuaVC ()
@property (nonatomic, strong) UITextView *editorView;
@property (nonatomic, strong) UITextView *consoleView;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *pasteButton;
@end

@implementation LuaVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
    [self log:@"[Lua] Ready"];
    if ([[LuaEngine shared] isAvailable]) {
        [self log:@"[Lua] liblua OK"];
    } else {
        [self log:@"[Lua] liblua NOT available"];
    }
    
    // Đăng ký nhận script tự động đẩy sang từ AI Agent
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleAutoPushScript:) 
                                                 name:@"PushScriptToLuaNotification" 
                                               object:nil];
}

- (void)handleAutoPushScript:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *script = userInfo[@"script"];
    if (script.length > 0) {
        self.editorView.text = script;
        [self log:@"[Lua] Đã tự động nhận script từ AI Agent! Đang thực thi..."];
        [self runTapped]; // Tự động chạy luôn
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    CGFloat y = 8;
    CGFloat pad = 8;

    CGFloat btnW = (w - pad * 5) / 4;
    CGFloat btnH = 36;

    self.runButton = [self makeButton:@"Run" x:pad y:y w:btnW h:btnH
                                color:[UIColor colorWithRed:0.20 green:0.70 blue:0.40 alpha:1.0]];
    [self.runButton addTarget:self action:@selector(runTapped)
             forControlEvents:UIControlEventTouchUpInside];

    self.stopButton = [self makeButton:@"Stop" x:pad * 2 + btnW y:y w:btnW h:btnH
                                 color:[UIColor colorWithRed:0.70 green:0.30 blue:0.30 alpha:1.0]];
    [self.stopButton addTarget:self action:@selector(stopTapped)
              forControlEvents:UIControlEventTouchUpInside];

    self.pasteButton = [self makeButton:@"Paste" x:pad * 3 + btnW * 2 y:y w:btnW h:btnH
                                  color:[UIColor colorWithRed:0.30 green:0.50 blue:0.70 alpha:1.0]];
    [self.pasteButton addTarget:self action:@selector(pasteTapped)
               forControlEvents:UIControlEventTouchUpInside];

    self.clearButton = [self makeButton:@"Clear" x:pad * 4 + btnW * 3 y:y w:btnW h:btnH
                                  color:[UIColor colorWithRed:0.40 green:0.40 blue:0.40 alpha:1.0]];
    [self.clearButton addTarget:self action:@selector(clearTapped)
               forControlEvents:UIControlEventTouchUpInside];

    y += btnH + 8;

    UILabel *editorLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 16)];
    editorLabel.text = @"EDITOR";
    editorLabel.textColor = [ToolTheme shared].textMuted;
    editorLabel.font = [[ToolTheme shared] monoFont:10];
    [self.view addSubview:editorLabel];
    y += 20;

    CGFloat editorH = 180;
    self.editorView = [[UITextView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, editorH)];
    self.editorView.backgroundColor = [ToolTheme shared].surface;
    self.editorView.textColor = [ToolTheme shared].textPrimary;
    self.editorView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.editorView.layer.cornerRadius = 4;
    self.editorView.layer.borderWidth = 1;
    self.editorView.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.editorView.text = @"-- Lua Script\n"
                           @"print(\"Hello from Lua!\")\n";
    self.editorView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.editorView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [self.view addSubview:self.editorView];
    y += editorH + 8;

    UILabel *consoleLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 16)];
    consoleLabel.text = @"CONSOLE OUTPUT";
    consoleLabel.textColor = [ToolTheme shared].textMuted;
    consoleLabel.font = [[ToolTheme shared] monoFont:10];
    [self.view addSubview:consoleLabel];
    y += 20;

    CGFloat consoleH = h - y - pad - 20;
    self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, consoleH)];
    self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    self.consoleView.textColor = [ToolTheme shared].success;
    self.consoleView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.consoleView.editable = NO;
    self.consoleView.layer.cornerRadius = 4;
    self.consoleView.layer.borderWidth = 1;
    self.consoleView.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.consoleView.text = @"-- Lua Console --\n";
    self.consoleView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.consoleView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    CGFloat pad = 8;
    CGFloat y = 8;
    CGFloat btnW = (w - pad * 5) / 4;
    CGFloat btnH = 36;

    self.runButton.frame = CGRectMake(pad, y, btnW, btnH);
    self.stopButton.frame = CGRectMake(pad * 2 + btnW, y, btnW, btnH);
    self.pasteButton.frame = CGRectMake(pad * 3 + btnW * 2, y, btnW, btnH);
    self.clearButton.frame = CGRectMake(pad * 4 + btnW * 3, y, btnW, btnH);
    y += btnH + 28;

    CGFloat editorH = 180;
    self.editorView.frame = CGRectMake(pad, y, w - pad * 2, editorH);
    y += editorH + 28;

    CGFloat consoleH = h - y - pad;
    if (consoleH < 80) consoleH = 80;
    self.consoleView.frame = CGRectMake(pad, y, w - pad * 2, consoleH);
}

- (UIButton *)makeButton:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h color:(UIColor *)color {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, h);
    b.backgroundColor = color;
    b.layer.cornerRadius = 4;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    [self.view addSubview:b];
    return b;
}

#pragma mark - Actions

- (void)runTapped {
    NSString *script = self.editorView.text;
    if (script.length == 0) return;

    [self.editorView resignFirstResponder];
    [self log:@"[Lua] Running script..."];

    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *result = [[LuaEngine shared] runScript:script];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws log:result];
        });
    });
}

- (void)stopTapped {
    [[LuaEngine shared] stop];
    [self log:@"[Lua] Stopped"];
}

- (void)pasteTapped {
    NSString *clip = [UIPasteboard generalPasteboard].string;
    if (clip.length > 0) {
        self.editorView.text = clip;
        [self log:@"[Lua] Pasted from clipboard"];
    }
}

- (void)clearTapped {
    self.consoleView.text = @"-- Lua Console --\n";
}

- (void)log:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *current = self.consoleView.text ?: @"";
        self.consoleView.text = [current stringByAppendingFormat:@"%@\n", text];
        [self.consoleView scrollRangeToVisible:NSMakeRange(self.consoleView.text.length - 1, 1)];
    });
}

- (void)reload {
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

@end
