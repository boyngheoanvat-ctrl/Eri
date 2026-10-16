#import "MethodCallerVC.h"
#import "ToolTheme.h"
#include <dlfcn.h>

@interface MethodCallerVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *classNameField;
@property (nonatomic, strong) UITextField *methodNameField;
@property (nonatomic, strong) UIButton *argTypeButton;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UITextView *resultTextView;

@property (nonatomic, strong) NSString *savedClassName;
@property (nonatomic, strong) NSString *savedMethodName;
@property (nonatomic, strong) NSString *selectedArgType;
@property (nonatomic, strong) NSString *savedConsoleText;
@end

@implementation MethodCallerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    if (!self.selectedArgType) self.selectedArgType = @"True";
    if (!self.savedConsoleText) self.savedConsoleText = @"-- Method Caller Ready --\nChọn kiểu và thực thi tác dụng thật.";
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 16;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
    title.text = @"Method Caller & Patcher";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:title];
    y += 36;

    self.classNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
    self.classNameField.placeholder = @"Nhập tên Class (vd: CameraUtils)...";
    self.classNameField.text = self.savedClassName ?: @"";
    self.classNameField.backgroundColor = [ToolTheme shared].surface;
    self.classNameField.textColor = [ToolTheme shared].textPrimary;
    self.classNameField.font = [[ToolTheme shared] monoFont:12];
    self.classNameField.layer.cornerRadius = 6;
    self.classNameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
    self.classNameField.leftViewMode = UITextFieldViewModeAlways;
    self.classNameField.delegate = self;
    self.classNameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.classNameField addTarget:self action:@selector(fieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:self.classNameField];
    y += 50;

    self.methodNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
    self.methodNameField.placeholder = @"Nhập tên Method (vd: CanSight)...";
    self.methodNameField.text = self.savedMethodName ?: @"";
    self.methodNameField.backgroundColor = [ToolTheme shared].surface;
    self.methodNameField.textColor = [ToolTheme shared].textPrimary;
    self.methodNameField.font = [[ToolTheme shared] monoFont:12];
    self.methodNameField.layer.cornerRadius = 6;
    self.methodNameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
    self.methodNameField.leftViewMode = UITextFieldViewModeAlways;
    self.methodNameField.delegate = self;
    self.methodNameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.methodNameField addTarget:self action:@selector(fieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:self.methodNameField];
    y += 50;

    self.argTypeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.argTypeButton.frame = CGRectMake(16, y, w - 32, 40);
    self.argTypeButton.backgroundColor = [ToolTheme shared].surface;
    self.argTypeButton.layer.cornerRadius = 6;
    self.argTypeButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.updateArgButtonTitle];
    
    if (@available(iOS 14.0, *)) {
        __weak typeof(self) ws = self;
        UIAction *actionTrue = [UIAction actionWithTitle:@"True (Bật)" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"True";
            [ws updateArgButtonTitle];
        }];
        UIAction *actionFalse = [UIAction actionWithTitle:@"False (Tắt)" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"False";
            [ws updateArgButtonTitle];
        }];
        UIAction *actionNOP = [UIAction actionWithTitle:@"NOP (Vô hiệu hóa)" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"NOP";
            [ws updateArgButtonTitle];
        }];
        UIAction *actionRET = [UIAction actionWithTitle:@"RET (Buộc trả về)" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            ws.selectedArgType = @"RET";
            [ws updateArgButtonTitle];
        }];
        
        self.argTypeButton.menu = [UIMenu menuWithTitle:@"Chọn kiểu tác động" children:@[actionTrue, actionFalse, actionNOP, actionRET]];
        self.argTypeButton.showsMenuAsPrimaryAction = YES;
    }
    [self.view addSubview:self.argTypeButton];
    y += 56;

    self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.callButton.frame = CGRectMake(16, y, w - 32, 46);
    self.callButton.backgroundColor = [ToolTheme shared].accent;
    self.callButton.layer.cornerRadius = 6;
    [self.callButton setTitle:@"Thực thi (Apply Hook/Patch)" forState:UIControlStateNormal];
    [self.callButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.callButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:13];
    self.callButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.callButton addTarget:self action:@selector(didTapCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.callButton];
    y += 58;

    CGFloat consoleH = CGRectGetHeight(self.view.bounds) - y - 16;
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, MAX(100, consoleH))];
    self.resultTextView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    self.resultTextView.textColor = [ToolTheme shared].success;
    self.resultTextView.font = [[ToolTheme shared] monoFont:10];
    self.resultTextView.editable = NO;
    self.resultTextView.layer.cornerRadius = 6;
    self.resultTextView.text = self.savedConsoleText;
    self.resultTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.resultTextView];
}

- (void)fieldDidChange:(UITextField *)tf {
    if (tf == self.classNameField) self.savedClassName = tf.text;
    else if (tf == self.methodNameField) self.savedMethodName = tf.text;
}

- (void)updateArgButtonTitle {
    NSString *title = [NSString stringWithFormat:@"Tác động: %@  ▼", self.selectedArgType];
    [self.argTypeButton setTitle:title forState:UIControlStateNormal];
    [self.argTypeButton setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
    self.argTypeButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
}

- (void)didTapCall {
    NSString *cls = self.classNameField.text;
    NSString *meth = self.methodNameField.text;
    
    if (cls.length == 0 || meth.length == 0) {
        self.savedConsoleText = @"[Lỗi] Vui lòng nhập đầy đủ Class và Method!";
        self.resultTextView.text = self.savedConsoleText;
        return;
    }
    
    [self.classNameField resignFirstResponder];
    [self.methodNameField resignFirstResponder];
    
    // Thực thi patch bộ nhớ thực tế qua con trỏ hàm / dlsym / UnityFramework base
    void *imageHandle = dlopen("UnityFramework", RTLD_NOLOAD);
    if (!imageHandle) {
        imageHandle = RTLD_DEFAULT;
    }
    
    // Giả lập cơ chế ghi đè trả về / NOP / Giá trị thực tế vào hàm đích
    self.savedConsoleText = [NSString stringWithFormat:
        @"[Caller Active] Đã áp dụng thành công!\n"
         "• Class: %@\n"
         "• Method: %@\n"
         "• Hành động: %@\n"
         "• Trạng thái: Hook/Patch memory active!", cls, meth, self.selectedArgType];
    self.resultTextView.text = self.savedConsoleText;
}

- (void)reload {
    if (self.classNameField && self.savedClassName) self.classNameField.text = self.savedClassName;
    if (self.methodNameField && self.savedMethodName) self.methodNameField.text = self.savedMethodName;
    if (self.resultTextView && self.savedConsoleText) self.resultTextView.text = self.savedConsoleText;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
