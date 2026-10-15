#import "LuaVC.h"
#import "LuaEngine.h"
#import "ToolTheme.h"

@interface LuaVC () <UITextViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
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
    
    // Tính toán lại chiều rộng 4 nút chuẩn xác theo chiều ngang khung chứa (trừ lề 2 bên và khoảng cách)
    CGFloat availableW = w - (pad * 5);
    CGFloat btnW = availableW / 4.0;
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
    editorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:editorLabel];
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
                           @"print(\"Hello from Lua!\")\n"
                           @"local x = 10 + 20\n"
                           @"print(\"x =\", x)\n"
                           @"for i = 1, 5 do\n"
                           @"  print(\"i =\", i)\n"
                           @"end";
    self.editorView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.editorView.autocapitalizationType = UITextAutocapitalizationTypeNone;
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
    self.consoleView.layer.borderWidth = 1;
    self.consoleView.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.consoleView.text = @"-- Lua Console --\n";
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

- (void)setScriptContent:(NSString *)content {
    if (content && content.length > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.editorView.text = content;
            [self log:@"[Lua AI] Đã nhận script mới từ AI Chat!"];
        });
    }
}

- (void)log:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *current = self.consoleView.text ?: @"";
        self.consoleView.text = [current stringByAppendingFormat:@"%@\n", text];
        [self.consoleView scrollRangeToVisible:NSMakeRange(self.consoleView.text.length - 1, 1)];
    });
}

- (void)reload {}

@end
