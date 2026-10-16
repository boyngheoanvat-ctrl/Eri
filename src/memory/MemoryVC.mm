#import "MemoryVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@interface MemoryVC ()
@property (nonatomic, strong) UITextView *logView;
@end

@implementation MemoryVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    @autoreleasepool {
        self.logView = [[UITextView alloc] initWithFrame:self.view.bounds];
        self.logView.backgroundColor = [UIColor clearColor];
        self.logView.textColor = [ToolTheme shared].textPrimary;
        self.logView.font = [[ToolTheme shared] monoFont:11];
        self.logView.text = @"[MemoryVC] Quản lý bộ nhớ & RVA Scanner đã kích hoạt qua Ghidra.";
        [self.view addSubview:self.logView];
    }
}
- (void)reload {}
@end
