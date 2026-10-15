#import "MemoryVC.h"
#import "ToolTheme.h"

@interface MemoryVC ()
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    
    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, 16, w - 105, 36)];
    self.searchField.placeholder = @"Nhập giá trị cần tìm (ví dụ: 100, 0x123)...";
    self.searchField.backgroundColor = [ToolTheme shared].surface;
    self.searchField.textColor = [ToolTheme shared].textPrimary;
    self.searchField.font = [[ToolTheme shared] monoFont:12];
    self.searchField.layer.cornerRadius = 4;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchField];
    
    self.searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.searchButton.frame = CGRectMake(w - 81, 16, 65, 36);
    self.searchButton.backgroundColor = [ToolTheme shared].accent;
    [self.searchButton setTitle:@"Tìm" forState:UIControlStateNormal];
    [self.searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.searchButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.searchButton.layer.cornerRadius = 4;
    self.searchButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:self.searchButton];
}

- (void)reload {
}

@end
