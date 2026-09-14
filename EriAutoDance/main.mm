#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

static bool g_ActiveOn = false;
static int g_ModifiedCount = 0;
static UILabel *g_StatusLabel = nil;
static UILabel *g_CountLabel = nil;

// Hàm thực hiện logic mod
void ApplyCombinedMod(bool enable) {
    int count = 0;
    @autoreleasepool {
        Class auditionGroupClass = objc_getClass("Dance.AuditionGroup");
        Class trackCtrlClass = objc_getClass("GuidTrackDanceNoteCtrl");

        if (enable) {
            if (auditionGroupClass && class_respondsToSelector(auditionGroupClass, @selector(findObjects))) {
                id objs = [auditionGroupClass performSelector:@selector(findObjects)];
                if (objs && [objs respondsToSelector:@selector(count)]) {
                    NSUInteger objCount = [[objs valueForKey:@"count"] unsignedIntegerValue];
                    for (NSUInteger i = 1; i <= objCount; i++) {
                        count++;
                    }
                }
            }

            if (trackCtrlClass && class_respondsToSelector(trackCtrlClass, @selector(findObjects))) {
                id ctrls = [trackCtrlClass performSelector:@selector(findObjects)];
                if (ctrls && [ctrls respondsToSelector:@selector(count)]) {
                    NSUInteger ctrlCount = [[ctrls valueForKey:@"count"] unsignedIntegerValue];
                    for (NSUInteger i = 1; i <= ctrlCount; i++) {
                        count++;
                    }
                }
            }
        }
    }
    g_ModifiedCount = count;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_CountLabel) {
            g_CountLabel.text = [NSString stringWithFormat:@"Objects: %d", g_ModifiedCount];
        }
    });
}

// Giao diện Menu Nổi (Floating Menu)
@interface EriMenuViewController : UIViewController
@end

@implementation EriMenuViewController {
    UIView *menuView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    menuView = [[UIView alloc] initWithFrame:CGRectMake(50, 100, 260, 210)];
    menuView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:0.9f];
    menuView.layer.cornerRadius = 12.0f;
    menuView.layer.borderWidth = 1.5f;
    menuView.layer.borderColor = [UIColor purpleColor].CGColor;
    [self.view addSubview:menuView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 30)];
    titleLabel.text = @"Mod By ERI NGUYỄN";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:titleLabel];
    
    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 55, 150, 30)];
    switchLabel.text = @"Auto Dance";
    switchLabel.textColor = [UIColor whiteColor];
    switchLabel.font = [UIFont systemFontOfSize:14];
    [menuView addSubview:switchLabel];
    
    UISwitch *toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(190, 55, 50, 30)];
    [toggleSwitch setOn:g_ActiveOn];
    [toggleSwitch addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:toggleSwitch];
    
    g_CountLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 95, 230, 25)];
    g_CountLabel.text = @"Objects: 0";
    g_CountLabel.textColor = [UIColor cyanColor];
    g_CountLabel.font = [UIFont systemFontOfSize:13];
    [menuView addSubview:g_CountLabel];
    
    g_StatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 125, 230, 40)];
    g_StatusLabel.text = @"Trạng thái: Sẵn sàng";
    g_StatusLabel.textColor = [UIColor lightGrayColor];
    g_StatusLabel.font = [UIFont systemFontOfSize:12];
    g_StatusLabel.numberOfLines = 2;
    [menuView addSubview:g_StatusLabel];
    
    UIButton *floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatBtn.frame = CGRectMake(20, 40, 45, 45);
    floatBtn.backgroundColor = [UIColor purpleColor];
    [floatBtn setTitle:@"ERI" forState:UIControlStateNormal];
    floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    floatBtn.layer.cornerRadius = 22.5f;
    [floatBtn addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:floatBtn];
}

- (void)toggleChanged:(UISwitch *)sender {
    g_ActiveOn = sender.isOn;
    if (g_ActiveOn) {
        g_StatusLabel.text = @"Đã BẬT. Đang theo dõi trận...";
        g_StatusLabel.textColor = [UIColor greenColor];
    } else {
        g_StatusLabel.text = @"Đã TẮT tính năng.";
        g_StatusLabel.textColor = [UIColor lightGrayColor];
    }
}

- (void)toggleMenuVisibility {
    menuView.hidden = !menuView.hidden;
}

@end

__attribute__((constructor)) static void initialize() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (true) {
            if (g_ActiveOn) {
                ApplyCombinedMod(true);
            }
            sleep(2);
        }
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication] windows].firstObject;
        }
        if (window) {
            UIViewController *rootVC = window.rootViewController;
            if (rootVC) {
                EriMenuViewController *menuVC = [[EriMenuViewController alloc] init];
                menuVC.view.frame = window.bounds;
                menuVC.view.userInteractionEnabled = YES;
                [rootVC addChildViewController:menuVC];
                [rootVC.view addSubview:menuVC.view];
                [menuVC didMoveToParentViewController:rootVC];
            }
        }
    });
}
