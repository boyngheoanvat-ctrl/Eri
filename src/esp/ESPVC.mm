#import "ESPVC.h"
#import "ToolTheme.h"
#include <dlfcn.h>

@interface ESPVC ()
@property (nonatomic, strong) UISwitch *boxSwitch;
@property (nonatomic, strong) UISwitch *lineSwitch;
@property (nonatomic, strong) UISwitch *distanceSwitch;
@property (nonatomic, strong) UISwitch *healthSwitch;
@property (nonatomic, strong) UITextView *statusView;
@end

@implementation ESPVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 16;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
    title.text = @"ESP Overlay Manager";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:title];
    y += 40;

    NSArray *titles = @[@"ESP Box (Khung nhân vật)", @"ESP Line (Đường kẻ)", @"ESP Distance (Khoảng cách)", @"ESP Health (Máu)"];
    NSArray *selectors = @[@"boxChanged:", @"lineChanged:", @"distanceChanged:", @"healthChanged:"];
    
    for (int i = 0; i < titles.count; i++) {
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 100, 32)];
        lbl.text = titles[i];
        lbl.textColor = [ToolTheme shared].textPrimary;
        lbl.font = [[ToolTheme shared] monoFont:12];
        lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.view addSubview:lbl];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 75, y, 50, 32)];
        sw.onTintColor = [ToolTheme shared].accent;
        sw.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [sw addTarget:self action:NSSelectorFromString(selectors[i]) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:sw];
        
        if (i == 0) self.boxSwitch = sw;
        else if (i == 1) self.lineSwitch = sw;
        else if (i == 2) self.distanceSwitch = sw;
        else if (i == 3) self.healthSwitch = sw;

        y += 46;
    }

    CGFloat statusH = CGRectGetHeight(self.view.bounds) - y - 16;
    self.statusView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, w - 32, MAX(80, statusH))];
    self.statusView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    self.statusView.textColor = [ToolTheme shared].success;
    self.statusView.font = [[ToolTheme shared] monoFont:10];
    self.statusView.editable = NO;
    self.statusView.layer.cornerRadius = 6;
    self.statusView.text = @"-- ESP Overlay Active --\nĐã sẵn sàng hiển thị trên Metal/OpenGL context.";
    self.statusView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.statusView];
}

- (void)boxChanged:(UISwitch *)sender {
    self.statusView.text = [NSString stringWithFormat:@"[ESP] Box ESP: %@", sender.isOn ? @"ON" : @"OFF"];
}

- (void)lineChanged:(UISwitch *)sender {
    self.statusView.text = [NSString stringWithFormat:@"[ESP] Line ESP: %@", sender.isOn ? @"ON" : @"OFF"];
}

- (void)distanceChanged:(UISwitch *)sender {
    self.statusView.text = [NSString stringWithFormat:@"[ESP] Distance ESP: %@", sender.isOn ? @"ON" : @"OFF"];
}

- (void)healthChanged:(UISwitch *)sender {
    self.statusView.text = [NSString stringWithFormat:@"[ESP] Health Bar ESP: %@", sender.isOn ? @"ON" : @"OFF"];
}

- (void)reload {}

@end
