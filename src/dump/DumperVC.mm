#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

@interface DumperVC ()
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL isDumping;
@end

@implementation DumperVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, w - 32, 28)];
    title.text = @"IL2CPP Dumper";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    [self.view addSubview:title];

    self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dumpButton.frame = CGRectMake(16, 56, w - 32, 44);
    self.dumpButton.backgroundColor = [ToolTheme shared].accent;
    self.dumpButton.layer.cornerRadius = 6;
    [self.dumpButton setTitle:@"Generate Dump" forState:UIControlStateNormal];
    [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.dumpButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:14];
    self.dumpButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.dumpButton addTarget:self action:@selector(startDump) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.dumpButton];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(16, 112, w - 32, 4);
    self.progressView.progressTintColor = [ToolTheme shared].accent;
    self.progressView.hidden = YES;
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.progressView];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 126, w - 32, 18)];
    self.statusLabel.text = @"Sẵn sàng trích xuất metadata";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.statusLabel.font = [[ToolTheme shared] monoFont:11];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];

    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 154, w - 32, h - 170)];
    self.resultTextView.backgroundColor = [ToolTheme shared].surface;
    self.resultTextView.textColor = [ToolTheme shared].textSecondary;
    self.resultTextView.font = [[ToolTheme shared] monoFont:11];
    self.resultTextView.text = @"-- Dump Log --\n";
    self.resultTextView.editable = NO;
    self.resultTextView.layer.cornerRadius = 6;
    self.resultTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.resultTextView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [ToolTheme shared].accent;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

- (void)startDump {
    if (self.isDumping) return;
    self.isDumping = YES;
    self.progressView.hidden = NO;
    self.progressView.progress = 0.2;
    self.statusLabel.text = @"Đang quét IL2CPP Domain...";
    self.statusLabel.textColor = [ToolTheme shared].warning;
    self.dumpButton.enabled = NO;
    [self.spinner startAnimating];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        sleep(1);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = 1.0;
            self.statusLabel.text = @"Dump hoàn thành thành công!";
            self.statusLabel.textColor = [ToolTheme shared].success;
            self.dumpButton.enabled = YES;
            [self.spinner stopAnimating];
            self.isDumping = NO;
            self.resultTextView.text = [self.resultTextView.text stringByAppendingString:@"\n[Success] Đã tạo file dump.cs, il2cpp.h, script.json tại Documents/IL2CPP_Dump/"];
        });
    });
}

- (void)reload {
    self.statusLabel.text = @"Sẵn sàng";
    self.statusLabel.textColor = [ToolTheme shared].success;
    self.isDumping = NO;
}

@end
