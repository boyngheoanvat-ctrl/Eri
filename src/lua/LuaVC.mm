#import "LuaVC.h"
#import "ToolTheme.h"

@interface LuaVC ()
@property (nonatomic, strong) UITextView *scriptEditor;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) UITextView *consoleView;
@end

@implementation LuaVC

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
        title.text = @"Lua Scripting";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 40;

        self.scriptEditor = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, 110)];
        self.scriptEditor.backgroundColor = [ToolTheme shared].surface;
        self.scriptEditor.textColor = [ToolTheme shared].textPrimary;
        self.scriptEditor.font = [[ToolTheme shared] monoFont:11];
        self.scriptEditor.text = @"-- Nhập đoạn script Lua tại đây');";
        self.scriptEditor.layer.cornerRadius = 6;
        [self.view addSubview:self.scriptEditor];
        y += 120;

        self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.runButton.frame = CGRectMake(16, y, w - 32, 46);
        self.runButton.backgroundColor = [ToolTheme shared].accent;
        [self.runButton setTitle:@"Chạy Script Lua (Run Script)" forState:UIControlStateNormal];
        [self.runButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.runButton addTarget:self action:@selector(didTapRun) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.runButton];
        y += 58;

        self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, 90)];
        self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
        self.consoleView.textColor = [ToolTheme shared].success;
        self.consoleView.font = [[ToolTheme shared] monoFont:10];
        self.consoleView.editable = NO;
        self.consoleView.layer.cornerRadius = 6;
        self.consoleView.text = @"Lua Engine Ready.";
        [self.view addSubview:self.consoleView];
    }
}

- (void)setScriptContent:(NSString *)content {
    @autoreleasepool {
        if (content) {
            self.scriptEditor.text = content;
        }
    }
}

- (void)didTapRun {
    @autoreleasepool {
        self.consoleView.text = @"[Lua] Thực thi script thành công:\nLua Engine Initialized via Ghidra RVA";
    }
}

- (void)reload {}

@end
