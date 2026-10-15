#import "ToolTheme.h"

@implementation ToolTheme

+ (instancetype)shared {
    static ToolTheme *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ToolTheme alloc] init]; });
    return instance;
}

#pragma mark - Background

- (UIColor *)background {
    return [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];
}

- (UIColor *)surface {
    return [UIColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:1.0];
}

- (UIColor *)surfaceAlt {
    return [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0];
}

#pragma mark - Text

- (UIColor *)textPrimary {
    return [UIColor colorWithRed:0.92 green:0.92 blue:0.94 alpha:1.0];
}

- (UIColor *)textSecondary {
    return [UIColor colorWithRed:0.65 green:0.65 blue:0.70 alpha:1.0];
}

- (UIColor *)textMuted {
    return [UIColor colorWithRed:0.45 green:0.45 blue:0.50 alpha:1.0];
}

#pragma mark - Accent

- (UIColor *)accent {
    return [UIColor colorWithRed:0.26 green:0.59 blue:0.98 alpha:1.0];
}

- (UIColor *)accentSoft {
    return [UIColor colorWithRed:0.26 green:0.59 blue:0.98 alpha:0.3];
}

- (UIColor *)success {
    return [UIColor colorWithRed:0.40 green:0.80 blue:0.45 alpha:1.0];
}

- (UIColor *)warning {
    return [UIColor colorWithRed:0.95 green:0.75 blue:0.30 alpha:1.0];
}

- (UIColor *)danger {
    return [UIColor colorWithRed:0.90 green:0.35 blue:0.35 alpha:1.0];
}

#pragma mark - UI Elements

- (UIColor *)divider {
    return [UIColor colorWithRed:0.20 green:0.20 blue:0.24 alpha:1.0];
} 

- (UIColor *)border {
    return [UIColor colorWithRed:0.25 green:0.25 blue:0.30 alpha:1.0];
}

- (UIColor *)selectedFill {
    return [UIColor colorWithRed:0.26 green:0.59 blue:0.98 alpha:0.25];
}

- (UIColor *)mutedFill {
    return [UIColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0];
}

#pragma mark - Fonts

- (UIFont *)monoFont:(CGFloat)size {
    UIFont *f = [UIFont fontWithName:@"Menlo" size:size];
    return f ?: [UIFont systemFontOfSize:size];
}

- (UIFont *)monoBoldFont:(CGFloat)size {
    UIFont *f = [UIFont fontWithName:@"Menlo-Bold" size:size];
    return f ?: [UIFont boldSystemFontOfSize:size];
}

@end
