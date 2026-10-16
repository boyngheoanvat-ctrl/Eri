#import "DumperVC.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

@interface DumperVC ()
@property (nonatomic, strong) UIButton *dumpButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (atomic, assign) BOOL isDumping;
@end

@implementation DumperVC

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
        title.text = @"IL2CPP Dumper & Ghidra RVA";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 50;

        self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.dumpButton.frame = CGRectMake(16, y, w - 32, 46);
        self.dumpButton.backgroundColor = [ToolTheme shared].accent;
        [self.dumpButton setTitle:@"Generate Ghidra Dump" forState:UIControlStateNormal];
        [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.dumpButton addTarget:self action:@selector(startDump) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.dumpButton];
    }
}

- (void)startDump {
    if (self.isDumping) return;
    self.isDumping = YES;
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            IL2CPPResolver *r = [IL2CPPResolver shared];
            if (!r || ![r resolve]) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool { ws.isDumping = NO; }
            });
        }
    });
}

- (void)reload { @autoreleasepool { self.isDumping = NO; } }

@end
