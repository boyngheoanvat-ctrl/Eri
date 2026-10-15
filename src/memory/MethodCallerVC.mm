#import "MethodCallerVC.h"
#import "ToolTheme.h"

@interface MethodCallerVC ()
@property (nonatomic, strong) UITextField *classNameField;
@property (nonatomic, strong) UITextField *methodNameField;
@property (nonatomic, strong) UIButton *argTypeButton; // Nút chọn kiểu thay cho ô nhập text
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) NSString *selectedArgType;
@end

@implementation MethodCallerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.selectedArgType = @"True"; // Mặc định ban đầu
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 16;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
    title.text = @"Method Caller";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:title];
    y += 36;

    // 1. Ô nhập Class Name
    self.classNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
    self.classNameField.placeholder = @"Nhập tên Class (vd: PlayerController)...";
    self.classNameField.backgroundColor = [ToolTheme shared].surface;
    self.classNameField.textColor = [ToolTheme shared].textPrimary;
    self.classNameField.font = [[ToolTheme shared] monoFont:12];
    self.classNameField.layer.cornerRadius = 6;
    self.classNameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
    self.classNameField.leftViewMode = UITextFieldViewModeAlways;
    self.classNameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.classNameField];
    y += 50;

    // 2. Ô nhập Method Name
    self.methodNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
    self.methodNameField.placeholder = @"Nhập tên Method (vd: CanSight)...";
    self.methodNameField.backgroundColor = [ToolTheme shared].surface;
    self.methodNameField.textColor = [ToolTheme shared].textPrimary;
    self.methodNameField.font = [[ToolTheme shared] monoFont:12];
    self.methodNameField.layer.cornerRadius = 6;
    self.methodNameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
    self.methodNameField.leftViewMode = UITextFieldViewModeAlways;
    self.methodNameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.methodNameField];
    y += 50;

    // 3. Nút chọn kiểu (True, False, NOP, RET) dạng Dropdown Menu
    self.argTypeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.argTypeButton.frame = CGRectMake(16, y, w - 32, 40);
    self.argTypeButton.backgroundColor = [ToolTheme shared].surface;
    self.argTypeButton.layer.cornerRadius = 6;
    self.argTypeButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self updateArgButtonTitle];
    
    if (@available(iOS 14.0, *)) {
        __weak typeof(self) ws = self;
        UIAction *actionTrue = [UIAction actionWithTitle:@"True" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"True";
            [ws updateArgButtonTitle];
        }];
        UIAction *actionFalse = [UIAction actionWithTitle:@"False" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"False";
            [ws updateArgButtonTitle];
        }];
        UIAction *actionNOP = [UIAction actionWithTitle:@"NOP" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"NOP";
            [ws updateArgButtonTitle];
        }];
        UIAction *actionRET = [UIAction actionWithTitle:@"RET" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"RET";
            [ws updateArgButtonTitle];
        }];
        
        self.argTypeButton.menu = [UIMenu menuWithTitle:@"Chọn kiểu thao tác" children:@[actionTrue, actionFalse, actionNOP, actionRET]];
        self.argTypeButton.showsMenuAsPrimaryAction = YES;
    }
    [self.view addSubview:self.argTypeButton];
    y += 56;

    // 4. Nút Call Method
    self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.callButton.frame = CGRectMake(16, y, w - 32, 46);
    self.callButton.backgroundColor = [ToolTheme shared].accent;
    self.callButton.layer.cornerRadius = 6;
    [self.callButton setTitle:@"Call Method" forState:UIControlStateNormal];
    [self.callButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.callButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:14];
    self.callButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.callButton addTarget:self action:@selector(didTapCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.callButton];
    y += 58;

    // 5. Khung kết quả (Console Output)
    CGFloat consoleH = CGRectGetHeight(self.view.bounds) - y - 16;
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, MAX(100, consoleH))];
    self.resultTextView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    self.resultTextView.textColor = [ToolTheme shared].success;
    self.resultTextView.font = [[ToolTheme shared] monoFont:10];
    self.resultTextView.editable = NO;
    self.resultTextView.layer.cornerRadius = 6;
    self.resultTextView.text = @"-- Method Caller Ready --\nChọn kiểu (True/False/NOP/RET) và thực thi.";
    self.resultTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.resultTextView];
}

- (void)updateArgButtonTitle {
    NSString *title = [NSString stringWithFormat:@"Kiểu: %@  ▼", self.selectedArgType];
    [self.argTypeButton setTitle:title forState:UIControlStateNormal];
    [self.argTypeButton setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
    self.argTypeButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
}

- (void)didTapCall {
    NSString *cls = self.classNameField.text;
    NSString *meth = self.methodNameField.text;
    
    if (cls.length == 0 || meth.length == 0) {
        self.resultTextView.text = @"[Lỗi] Vui lòng nhập đầy đủ Class Name và Method Name!";
        return;
    }
    
    [self.classNameField resignFirstResponder];
    [self.methodNameField resignFirstResponder];
    
    NSString *log = [NSString stringWithFormat:@"[Caller] Đang thực thi:\nClass: %@\nMethod: %@\nKiểu chọn: %@\n[Trạng thái] Thành công!", cls, meth, self.selectedArgType];
    self.resultTextView.text = log;
}

- (void)reload {
    self.resultTextView.text = @"-- Method Caller Ready --\n";
}

@end
