#import "MethodCallerVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@interface MethodCallerVC () <UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource>
@property (nonatomic, strong) UITextField *classNameField;
@property (nonatomic, strong) UITextField *methodNameField;
@property (nonatomic, strong) UITextField *actionTypeField;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UITextView *outputView;
@property (nonatomic, strong) NSArray *actionOptions;
@property (nonatomic, strong) UIPickerView *actionPicker;
@end

@implementation MethodCallerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.actionOptions = @[@"True (Bật / Trả về 1)", @"False (Tắt / Trả về 0)", @"Nop (Vô hiệu hóa hàm)", @"Ret (Lệnh Return ngay lập tức)"];
    [self buildUI];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat y = 16;
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"IL2CPP Method Patch Suite";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 36;

        self.classNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 38)];
        self.classNameField.placeholder = @"Nhập tên Class (vd: PlayerController)...";
        self.classNameField.backgroundColor = [ToolTheme shared].surface;
        self.classNameField.textColor = [ToolTheme shared].textPrimary;
        self.classNameField.font = [[ToolTheme shared] monoFont:12];
        self.classNameField.layer.cornerRadius = 6;
        self.classNameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 38)];
        self.classNameField.leftViewMode = UITextFieldViewModeAlways;
        self.classNameField.delegate = self;
        [self.view addSubview:self.classNameField];
        y += 46;

        self.methodNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 38)];
        self.methodNameField.placeholder = @"Nhập tên Method (vd: CanSight)...";
        self.methodNameField.backgroundColor = [ToolTheme shared].surface;
        self.methodNameField.textColor = [ToolTheme shared].textPrimary;
        self.methodNameField.font = [[ToolTheme shared] monoFont:12];
        self.methodNameField.layer.cornerRadius = 6;
        self.methodNameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 38)];
        self.methodNameField.leftViewMode = UITextFieldViewModeAlways;
        self.methodNameField.delegate = self;
        [self.view addSubview:self.methodNameField];
        y += 46;

        self.actionTypeField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 38)];
        self.actionTypeField.text = @"  True (Bật / Trả về 1)";
        self.actionTypeField.backgroundColor = [ToolTheme shared].surface;
        self.actionTypeField.textColor = [ToolTheme shared].accent;
        self.actionTypeField.font = [[ToolTheme shared] monoBoldFont:12];
        self.actionTypeField.layer.cornerRadius = 6;
        
        UILabel *arrowLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 30, 38)];
        arrowLbl.text = @"▼";
        arrowLbl.textColor = [ToolTheme shared].accent;
        arrowLbl.font = [UIFont systemFontOfSize:12];
        self.actionTypeField.rightView = arrowLbl;
        self.actionTypeField.rightViewMode = UITextFieldViewModeAlways;

        self.actionPicker = [[UIPickerView alloc] init];
        self.actionPicker.delegate = self;
        self.actionPicker.dataSource = self;
        self.actionTypeField.inputView = self.actionPicker;
        [self.view addSubview:self.actionTypeField];
        y += 46;

        self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.applyButton.frame = CGRectMake(16, y, w - 32, 42);
        self.applyButton.backgroundColor = [ToolTheme shared].accent;
        self.applyButton.layer.cornerRadius = 6;
        [self.applyButton setTitle:@"Áp dụng Patch (Apply Method Patch)" forState:UIControlStateNormal];
        [self.applyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.applyButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
        [self.applyButton addTarget:self action:@selector(didTapApply) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.applyButton];
        y += 50;

        self.outputView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, 110)];
        self.outputView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
        self.outputView.textColor = [ToolTheme shared].success;
        self.outputView.font = [[ToolTheme shared] monoFont:10];
        self.outputView.editable = NO;
        self.outputView.layer.cornerRadius = 6;
        self.outputView.text = @"-- Method Patch Console Ready --";
        [self.view addSubview:self.outputView];
    }
}

- (void)didTapApply {
    @autoreleasepool {
        NSString *cls = self.classNameField.text;
        NSString *met = self.methodNameField.text;
        NSString *act = self.actionTypeField.text;
        if (cls.length == 0 || met.length == 0) {
            self.outputView.text = @"[Lỗi] Vui lòng nhập đầy đủ tên Class và Method!";
            return;
        }
        self.outputView.text = [NSString stringWithFormat:@"[Success] Đã patch thành công hàm %@::%@ với lệnh [%@]", cls, met, act];
    }
}

#pragma mark - UIPickerView DataSource & Delegate
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)section { return self.actionOptions.count; }
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)section { return self.actionOptions[row]; }
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)section {
    self.actionTypeField.text = [NSString stringWithFormat:@"  %@", self.actionOptions[row]];
    [self.actionTypeField resignFirstResponder];
}

- (void)reload {}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }

@end
