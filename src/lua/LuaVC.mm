#import "LuaVC.h"
#import "ToolTheme.h"

@interface LuaVC ()
@property (nonatomic, strong) UITextView *scriptTextView;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UIButton *clearButton;
@end

@implementation LuaVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    self.scriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 16, w - 32, h - 74)];
    self.scriptTextView.backgroundColor = [ToolTheme shared].surface;
    self.scriptTextView.textColor = [ToolTheme shared].textPrimary;
    self.scriptTextView.font = [[ToolTheme shared] monoFont:11];
    self.scriptTextView.text = @"-- [Eri Lua Engine] Sẵn sàng thực thi script\nprint(\"Hello Eri Nguyễn!\")";
    self.scriptTextView.layer.cornerRadius = 6;
    self.scriptTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scriptTextView];
    
    CGFloat btnY = h - 50;
    CGFloat btnW = (w - 32 - 16) / 3.0;
    
    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runButton.frame = CGRectMake(16, btnY, btnW, 36);
    self.runButton.backgroundColor = [ToolTheme shared].success;
    [self.runButton setTitle:@"Run" forState:UIControlStateNormal];
    [self.runButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.runButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.runButton.layer.cornerRadius = 4;
    self.runButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.runButton addTarget:self action:@selector(didTapRun) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.runButton];
    
    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.stopButton.frame = CGRectMake(16 + btnW + 8, btnY, btnW, 36);
    self.stopButton.backgroundColor = [ToolTheme shared].danger;
    [self.stopButton setTitle:@"Stop" forState:UIControlStateNormal];
    [self.stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.stopButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.stopButton.layer.cornerRadius = 4;
    self.stopButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.stopButton addTarget:self action:@selector(didTapStop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stopButton];
    
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearButton.frame = CGRectMake(16 + (btnW + 8) * 2, btnY, btnW, 36);
    self.clearButton.backgroundColor = [ToolTheme shared].warning;
    [self.clearButton setTitle:@"Clear" forState:UIControlStateNormal];
    [self.clearButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clearButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.clearButton.layer.cornerRadius = 4;
    self.clearButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    [self.clearButton addTarget:self action:@selector(didTapClear) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearButton];
}

- (void)didTapRun {
    NSLog(@"[Lua] Đang thực thi script Lua...");
}

- (void)didTapStop {
    NSLog(@"[Lua] Đã dừng script Lua.");
}

- (void)didTapClear {
    self.scriptTextView.text = @"-- Script cleared --\n";
}

- (void)setScriptContent:(NSString *)content {
    if (content && content.length > 0) {
        self.scriptTextView.text = content;
    }
}

- (void)reload {
}

@end
