#import "ToolRailButton.h"
#import "ToolTheme.h"

@interface ToolRailButton ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *activeBar;
@end

@implementation ToolRailButton

- (instancetype)initWithTitle:(NSString *)title symbol:(NSString *)symbol {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.symbol = symbol;
        self.title = title;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];

    // Active bar (bên trái)
    self.activeBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 3, 0)];
    self.activeBar.backgroundColor = [ToolTheme shared].accent;
    self.activeBar.hidden = YES;
    [self addSubview:self.activeBar];

    // Icon (dùng text làm icon vì không có SF Symbols trên iOS cũ)
    self.iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.tintColor = [ToolTheme shared].textSecondary;
    [self addSubview:self.iconView];

    // Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = self.title;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [ToolTheme shared].textSecondary;
    self.titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
    [self addSubview:self.titleLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);

    self.activeBar.frame = CGRectMake(0, h * 0.2, 3, h * 0.6);

    self.iconView.frame = CGRectMake((w - 24) / 2.0, h * 0.2, 24, 24);
    self.titleLabel.frame = CGRectMake(0, h * 0.65, w, 12);
}

- (void)setActive:(BOOL)active {
    _active = active;

    self.activeBar.hidden = !active;
    self.iconView.tintColor = active
        ? [ToolTheme shared].accent
        : [ToolTheme shared].textSecondary;
    self.titleLabel.textColor = active
        ? [ToolTheme shared].accent
        : [ToolTheme shared].textSecondary;
    self.backgroundColor = active
        ? [ToolTheme shared].selectedFill
        : [UIColor clearColor];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.alpha = 0.6;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.alpha = 1.0;
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.alpha = 1.0;
}

@end
