#import "MethodCallerVC.h"
#import "MethodCaller.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

@interface MethodCallerVC ()
@property (nonatomic, strong) UITextField *classField;
@property (nonatomic, strong) UITextField *methodField;
@property (nonatomic, strong) UITextField *argsField;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation MethodCallerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    CGFloat y = 10;

    self.classField = [self makeField:@"Class name (VD: PlayerController)" y:y];
    y += 44;
    self.methodField = [self makeField:@"Method name (VD: SetHealth)" y:y];
    y += 44;
    self.argsField = [self makeField:@"Args (cach nhau dau phay)" y:y];
    y += 54;

    self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.callButton.frame = CGRectMake(10, y, w - 20, 44);
    self.callButton.backgroundColor = [ToolTheme shared].accent;
    self.callButton.layer.cornerRadius = 6;
    [self.callButton setTitle:@"Call Method" forState:UIControlStateNormal];
    [self.callButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.callButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:14];
    [self.callButton addTarget:self action:@selector(callTapped)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.callButton];
    y += 54;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y, w - 20, 20)];
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].textMuted;
    self.statusLabel.font = [[ToolTheme shared] monoFont:10];
    [self.view addSubview:self.statusLabel];
    y += 26;

    self.resultView = [[UITextView alloc] initWithFrame:CGRectMake(10, y, w - 20, h - y - 20)];
    self.resultView.backgroundColor = [ToolTheme shared].surface;
    self.resultView.textColor = [ToolTheme shared].textPrimary;
    self.resultView.font = [[ToolTheme shared] monoFont:11];
    self.resultView.editable = NO;
    self.resultView.layer.cornerRadius = 6;
    self.resultView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.resultView.text = @"-- Ket qua --\n";
    [self.view addSubview:self.resultView];
}

- (UITextField *)makeField:(NSString *)placeholder y:(CGFloat)y {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(10, y, w - 20, 36)];
    f.backgroundColor = [ToolTheme shared].surface;
    f.textColor = [ToolTheme shared].textPrimary;
    f.font = [[ToolTheme shared] monoFont:12];
    f.layer.borderWidth = 1;
    f.layer.borderColor = [ToolTheme shared].border.CGColor;
    f.layer.cornerRadius = 4;
    f.placeholder = placeholder;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 36)];
    f.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:f];
    return f;
}

- (void)callTapped {
    NSString *clsName = self.classField.text;
    NSString *mName = self.methodField.text;
    if (clsName.length == 0 || mName.length == 0) {
        [self log:@"Nhap class + method"];
        return;
    }

    [self.view endEditing:YES];
    [self log:[NSString stringWithFormat:@"> Call %@.%@", clsName, mName]];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) { [self log:@"IL2CPP not resolved"]; return; }

    Il2CppDomain *domain = [r domain_get];
    if (!domain) { [self log:@"No domain"]; return; }

    NSString *clsLower = clsName.lowercaseString;

    for (int a = 0; a < domain->assembly_count; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        void *imgPtr = *(void **)asm_;
        if (!imgPtr) continue;
        Il2CppImage *image = (Il2CppImage *)imgPtr;
        if (!image || !image->name) continue;

        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *klass = [r image_get_class:image index:i];
            if (!klass) continue;
            const char *cname = [r class_get_name:klass];
            if (!cname) continue;
            NSString *name = [NSString stringWithUTF8String:cname];
            if (![name.lowercaseString containsString:clsLower]) continue;

            uint16_t mCount = 0;
            const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
            for (uint16_t j = 0; j < mCount; j++) {
                const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
                if (!mn) continue;
                NSString *mn_str = [NSString stringWithUTF8String:mn];
                if (![mn_str isEqualToString:mName]) continue;

                [self log:[NSString stringWithFormat:@"Tim thay: %@", mn_str]];

                NSMutableArray *args = [NSMutableArray array];
                if (self.argsField.text.length > 0) {
                    NSArray *parts = [self.argsField.text componentsSeparatedByString:@","];
                    for (NSString *p in parts) {
                        NSString *trim = [p stringByTrimmingCharactersInSet:
                                          [NSCharacterSet whitespaceCharacterSet]];
                        if (trim.length > 0) [args addObject:trim];
                    }
                }

                id result = [[MethodCaller shared]
                    callMethod:(MethodInfo *)mList[j]
                    onObject:nil
                    args:args];

                [self log:[NSString stringWithFormat:@"Ket qua: %@", result]];
                if (mList) free(mList);
                return;
            }
            if (mList) free(mList);
            [self log:@"Khong tim thay method"];
            return;
        }
    }

    [self log:@"Khong tim thay class"];
}

- (void)log:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *current = self.resultView.text ?: @"";
        self.resultView.text = [current stringByAppendingFormat:@"%@\n", text];
        [self.resultView scrollRangeToVisible:NSMakeRange(self.resultView.text.length - 1, 1)];
        self.statusLabel.text = text;
    });
}

- (void)reload {
    self.statusLabel.text = @"San sang";
}

@end
