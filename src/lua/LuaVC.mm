#import "LuaVC.h"
#import "ToolTheme.h"

@interface LuaVC ()
@property (nonatomic, strong) UITextView *scriptTextView;
@end

@implementation LuaVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    self.scriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 16, w - 32, h - 32)];
    self.scriptTextView.backgroundColor = [ToolTheme shared].surface;
    self.scriptTextView.textColor = [ToolTheme shared].textPrimary;
    self.scriptTextView.font = [[ToolTheme shared] monoFont:11];
    self.scriptTextView.text = @"-- Lua Script\nprint(\"Hello from Lua!\")";
    self.scriptTextView.layer.cornerRadius = 6;
    self.scriptTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scriptTextView];
}

- (void)setScriptContent:(NSString *)content {
    if (content && content.length > 0) {
        self.scriptTextView.text = content;
    }
}

- (void)reload {
}

@end
