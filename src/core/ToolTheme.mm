#import "ToolTheme.h"

@implementation ToolTheme

+ (instancetype)shared {
    static ToolTheme *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ToolTheme alloc] init];
    });
    return instance;
}

- (UIColor *)background {
    return [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:0.95];
}

- (UIColor *)surface {
    return [UIColor colorWithRed:0.15 green:0.15 blue:0.16 alpha:1.0];
}

- (UIColor *)surfaceAlt {
    return [UIColor colorWithRed:0.18 green:0.18 blue:0.19 alpha:1.0];
}

- (UIColor *)border {
    return [UIColor colorWithRed:0.25 green:0.25 blue:0.27 alpha:1.0];
}

- (UIColor *)textPrimary {
    return [UIColor colorWithRed:0.83 green:0.83 blue:0.83 alpha:1.0];
}

- (UIColor *)textSecondary {
    return [UIColor colorWithRed:0.70 green:0.70 blue:0.70 alpha:1.0];
}

- (UIColor *)textMuted {
    return [UIColor colorWithRed:0.52 green:0.52 blue:0.52 alpha:1.0];
}

- (UIColor *)accent {
    return [UIColor colorWithRed:0.00 green:0.90 blue:0.46 alpha:1.0];
}

- (UIColor *)accentSoft {
    return [UIColor colorWithRed:0.00 green:0.90 blue:0.46 alpha:0.2];
}

- (UIColor *)success {
    return [UIColor colorWithRed:0.18 green:0.80 blue:0.44 alpha:1.0];
}

- (UIColor *)warning {
    return [UIColor colorWithRed:0.95 green:0.77 blue:0.06 alpha:1.0];
}

- (UIColor *)danger {
    return [UIColor colorWithRed:0.90 green:0.30 blue:0.24 alpha:1.0];
}

- (UIColor *)divider {
    return [UIColor colorWithRed:0.22 green:0.22 blue:0.24 alpha:1.0];
}

- (UIColor *)selectedFill {
    return [UIColor colorWithRed:0.20 green:0.25 blue:0.22 alpha:1.0];
}

- (UIColor *)mutedFill {
    return [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:1.0];
}

- (UIFont *)monoFont:(CGFloat)size {
    return [UIFont fontWithName:@"Menlo" size:size] ?: [UIFont systemFontOfSize:size];
}

- (UIFont *)monoBoldFont:(CGFloat)size {
    return [UIFont fontWithName:@"Menlo-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size];
}

@end
