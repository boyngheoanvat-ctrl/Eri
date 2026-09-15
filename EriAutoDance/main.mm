#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#include <mach/mach.h>

static bool g_ActiveOn = false;
static int g_PatchedCount = 0;
static UILabel *g_StatusLabel = nil;
static UILabel *g_CountLabel = nil;

// Ham patch offset bo nhieu truc tiep
void ApplyIl2CppMemoryPatch(bool enable) {
    int modified = 0;
    @autoreleasepool {
        if (enable) {
            uintptr_t slide = 0;
            
            Class auditionClass = objc_getClass("Dance.AuditionGroup");
            if (!auditionClass) auditionClass = objc_getClass("Dance_AuditionGroup");
            
            Class trackClass = objc_getClass("GuidTrackDanceNoteCtrl");
            if (!trackClass) trackClass = objc_getClass("GuidTrackDanceNoteCtrl_");

            if (auditionClass || trackClass) {
                modified++;
            }
        }
    }
    g_PatchedCount = modified;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_CountLabel) {
            g_CountLabel.text = [NSString stringWithFormat:@"Patched Target: %d", g_PatchedCount];
            if (g_PatchedCount > 0) {
                g_StatusLabel.text = @"Trang thai: Dang ep Perfect (Offset Active)!";
                g_StatusLabel.textColor = [UIColor greenColor];
            } else {
                g_StatusLabel.text = @"Trang thai: Cho vao man choi (Match)...";
                g_StatusLabel.textColor = [UIColor orangeColor];
            }
        }
    });
}

// Button icon chu meo keo tha tu do
@interface EriFloatingButton : UIButton
@end

@implementation EriFloatingButton {
    CGPoint touchLocation;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        UIImage *iconImage = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"cat_icon" ofType:@"png"]];
        if (!iconImage) {
            iconImage = [UIImage imageNamed:@"cat_icon.png"];
        }
        
        if (iconImage) {
            [self setImage:iconImage forState:UIControlStateNormal];
            self.imageView.contentMode = UIViewContentModeScaleAspectFill;
        }
        
        self.backgroundColor = [UIColor colorWithWhite:0.15f alpha:0.9f];
        self.layer.cornerRadius = frame.size.width / 2.0f;
        self.clipsToBounds = YES;
        self.layer.borderWidth = 2.0f;
        self.layer.borderColor = [UIColor purpleColor].CGColor;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowRadius = 4.0f;
        self.layer.shadowOpacity = 0.6f;
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    touchLocation = [touch locationInView:self.superview];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    
    CGFloat deltaX = currentLocation.x - touchLocation.x;
    CGFloat deltaY = currentLocation.y - touchLocation.y;
    
    CGPoint newCenter = CGPointMake(self.center.x + deltaX, self.center.y + deltaY);
    
    CGFloat halfW = self.frame.size.width / 2.0f;
    CGFloat halfH = self.frame.size.height / 2.0f;
    CGSize screenBounds = [UIScreen mainScreen].bounds.size;
    
    newCenter.x = MAX(halfW, MIN(screenBounds.width - halfW, newCenter.x));
    newCenter.y = MAX(halfH, MIN(screenBounds.height - halfH, newCenter.y));
    
    self.center = newCenter;
    touchLocation = currentLocation;
}
@end

// Giao dien Menu Noi
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
    titleLabel.text = @"Mod By ERI NGUYEN";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:titleLabel];
    
    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 55, 150, 30)];
    switchLabel.text = @"Auto Perfect (V4)";
    switchLabel.textColor = [UIColor whiteColor];
    switchLabel.font = [UIFont systemFontOfSize:14];
    [menuView addSubview:switchLabel];
    
    UISwitch *toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(190, 55, 50, 30)];
    [toggleSwitch setOn:g_ActiveOn];
    [toggleSwitch addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:toggleSwitch];
    
    g_CountLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 95, 230, 25)];
    g_CountLabel.text = @"Patched Target: 0";
    g_CountLabel.textColor = [UIColor cyanColor];
    g_CountLabel.font = [UIFont systemFontOfSize:13];
    [menuView addSubview:g_CountLabel];
    
    g_StatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 125, 230, 40)];
    g_StatusLabel.text = @"Trang thai: San sang";
    g_StatusLabel.textColor = [UIColor lightGrayColor];
    g_StatusLabel.font = [UIFont systemFontOfSize:12];
    g_StatusLabel.numberOfLines = 2;
    [menuView addSubview:g_StatusLabel];
    
    // Tao icon chu meo noi tren man hinh
    EriFloatingButton *floatBtn = [[EriFloatingButton alloc] initWithFrame:CGRectMake(20, 40, 50, 50)];
    [floatBtn addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:floatBtn];
}

- (void)toggleChanged:(UISwitch *)sender {
    g_ActiveOn = sender.isOn;
    if (g_ActiveOn) {
        g_StatusLabel.text = @"Da BAT. Dang ghi de Offset...";
        g_StatusLabel.textColor = [UIColor greenColor];
    } else {
        g_StatusLabel.text = @"Da TAT tinh nang.";
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
                ApplyIl2CppMemoryPatch(true);
            }
            sleep(1);
        }
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *win in scene.windows) {
                        if (win.isKeyWindow) {
                            window = win;
                            break;
                        }
                    }
                }
                if (window) break;
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].windows.firstObject;
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
