#import "MethodCallerVC.h"
#import "ToolTheme.h"

@interface MethodCallerVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *classField;
@property (nonatomic, strong) UITextField *methodField;
@property (nonatomic, strong) UITextField *argsField;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UITextView *resultTextView;
@end

@implementation MethodCallerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    // 1. Ô nhập Class Name
    self.classField = [[UITextField alloc] initWithFrame:CGRectMake(16, 16, w - 32, 36)];
    self.classField.placeholder = @"Class name (VD: PlayerController)";
    self.classField.backgroundColor = [ToolTheme shared].surface;
    self.classField.textColor = [ToolTheme shared].textPrimary;
    self.classField.font = [[ToolTheme shared] monoFont:12];
    self.classField.layer.cornerRadius = 4;
    self.classField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.classField.leftViewMode = UITextFieldViewModeAlways;
    self.classField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.classField];
    
    // 2. Ô nhập Method Name
    self.methodField = [[UITextField alloc] initWithFrame:CGRectMake(16, 64, w - 32, 36)];
    self.methodField.placeholder = @"Method name (VD: SetHealth)";
    self.methodField.backgroundColor = [ToolTheme shared].surface;
    self.methodField.textColor = [ToolTheme shared].textPrimary;
    self.methodField.font = [[ToolTheme shared] monoFont:12];
    self.methodField.layer.cornerRadius = 4;
    self.methodField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.methodField.leftViewMode = UITextFieldViewModeAlways;
    self.methodField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.methodField];
    
    // 3. Ô nhập Args
    self.argsField = [[UITextField alloc] initWithFrame:CGRectMake(16, 112, w - 32, 36)];
    self.argsField.placeholder = @"Args (cach nhau dau phay)";
    self.argsField.backgroundColor = [ToolTheme shared].surface;
    self.argsField.textColor = [ToolTheme shared].textPrimary;
    self.argsField.font = [[ToolTheme shared] monoFont:12];
    self.argsField.layer.cornerRadius = 4;
    self.argsField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.argsField.leftViewMode = UITextFieldViewModeAlways;
    self.argsField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.argsField];
    
    // 4. Nút Call Method (Tự động co giãn theo khung kéo)
    self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.callButton.frame = CGRectMake(16, 164, w - 32, 44);
    self.callButton.backgroundColor = [ToolTheme shared].accent;
    [self.callButton setTitle:@"Call Method" forState:UIControlStateNormal];
    [self.callButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.callButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:13];
    self.callButton.layer.cornerRadius = 6;
    self.callButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.callButton addTarget:self action:@selector(didTapCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.callButton];
    
    // 5. Label trạng thái / kết quả phía dưới
    UILabel *statusTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 222, w - 32, 18)];
    statusTitle.text = @"San sang";
    statusTitle.textColor = [ToolTheme shared].textMuted;
    statusTitle.font = [[ToolTheme shared] monoFont:11];
    statusTitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:statusTitle];
    
    // 6. Text View hiển thị kết quả log
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 246, w - 32, h - 262)];
    self.resultTextView.backgroundColor = [ToolTheme shared].surface;
    self.resultTextView.textColor = [ToolTheme shared].textSecondary;
    self.resultTextView.font = [[ToolTheme shared] monoFont:11];
    self.resultTextView.text = @"-- Ket qua --\n";
    self.resultTextView.editable = NO;
    self.resultTextView.layer.cornerRadius = 6;
    self.resultTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.resultTextView];
}

- (void)didTapCall {
    NSString *cls = self.classField.text;
    NSString *method = self.methodField.text;
    if (cls.length == 0 || method.length == 0) {
        self.resultTextView.text = [self.resultTextView.text stringByAppendingString:@"\n[Error] Vui long nhap Class name va Method name!"];
        return;
    }
    self.resultTextView.text = [self.resultTextView.text stringByAppendingFormat:@"\n[Calling] %@.%@...", cls, method];
}

- (void)reload {
    self.resultTextView.text = @"-- Ket qua --\n";
}

@end
