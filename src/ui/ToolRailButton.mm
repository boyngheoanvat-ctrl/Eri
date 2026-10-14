#import "ToolRailButton.h"
#import "ToolTheme.h"

@interface ToolRailButton ()
@property (nonatomic, strong) UILabel *iconLabel;
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
    self.activeBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.activeBar.backgroundColor = [ToolTheme shared].accent;
    self.activeBar.hidden = YES;
    [self addSubview:self.activeBar];

    // Icon label (không dùng UIImageView vì không có SF Symbols)
    self.iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.iconLabel.textAlignment = NSTextAlignmentCenter;
    self.iconLabel.textColor = [ToolTheme shared].textSecondary;
    self.iconLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.iconLabel.text = self.symbol;
    [self addSubview:self.iconLabel];

    // Title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = self.title;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [ToolTheme shared].textSecondary;
    self.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    [self addSubview:self.titleLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);

    // Active bar (3px, cao 60% giữa)
    self.activeBar.frame = CGRectMake(0, h * 0.2, 3, h * 0.6);

    // Icon (cao 30px, ở trên)
    self.iconLabel.frame = CGRectMake(0, h * 0.18, w, 30);

    // Title (cao 16px, ở dưới icon)
    self.titleLabel.frame = CGRectMake(0, h * 0.62, w, 16);
}

- (void)setActive:(BOOL)active {
    _active = active;

    self.activeBar.hidden = !active;

    if (active) {
        self.iconLabel.textColor = [ToolTheme shared].accent;
        self.titleLabel.textColor = [ToolTheme shared].accent;
        self.backgroundColor = [ToolTheme shared].selectedFill;
    } else {
        self.iconLabel.textColor = [ToolTheme shared].textSecondary;
        self.titleLabel.textColor = [ToolTheme shared].textSecondary;
        self.backgroundColor = [UIColor clearColor];
    }
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
