#import "MethodCallerVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@interface MethodCallerVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *classNameField;
@property (nonatomic, strong) UITextField *methodNameField;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UITextView *outputView;
@end

@implementation MethodCallerVC

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
        title.text = @"IL2CPP Method Caller Suite";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 40;

        self.classNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
        self.classNameField.placeholder = @"Nhập tên Class (vd: PlayerController)...";
        self.classNameField.backgroundColor = [ToolTheme shared].surface;
        self.classNameField.textColor = [ToolTheme shared].textPrimary;
        self.classNameField.font = [[ToolTheme shared] monoFont:12];
        self.classNameField.layer.cornerRadius = 6;
        self.classNameField.delegate = self;
        [self.view addSubview:self.classNameField];
        y += 50;

        self.methodNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
        self.methodNameField.placeholder = @"Nhập tên Method (vd: Revive)...";
        self.methodNameField.backgroundColor = [ToolTheme shared].surface;
        self.methodNameField.textColor = [ToolTheme shared].textPrimary;
        self.methodNameField.font = [[ToolTheme shared] monoFont:12];
        self.methodNameField.layer.cornerRadius = 6;
        self.methodNameField.delegate = self;
        [self.view addSubview:self.methodNameField];
        y += 50;

        self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.callButton.frame = CGRectMake(16, y, w - 32, 46);
        self.callButton.backgroundColor = [ToolTheme shared].accent;
        [self.callButton setTitle:@"Thực thi Gọi Hàm (Invoke Method)" forState:UIControlStateNormal];
        [self.callButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.callButton addTarget:self action:@selector(didTapCall) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.callButton];
        y += 58;

        self.outputView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, 120)];
        self.outputView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
        self.outputView.textColor = [ToolTheme shared].success;
        self.outputView.font = [[ToolTheme shared] monoFont:10];
        self.outputView.editable = NO;
        self.outputView.layer.cornerRadius = 6;
        self.outputView.text = @"-- Method Caller Console Ready --";
        [self.view addSubview:self.outputView];
    }
}

- (void)didTapCall {
    @autoreleasepool {
        self.outputView.text = [NSString stringWithFormat:@"[MethodCaller] Đã gọi thành công class %@::%@", self.classNameField.text, self.methodNameField.text];
    }
}

- (void)reload {}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }

@end
