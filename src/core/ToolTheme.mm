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
    // Xám đậm đặc trưng ImGui Dark Theme (#1E1E1E)
    return [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:0.95];
}

- (UIColor *)surface {
    // Xám khung panel (#252526)
    return [UIColor colorWithRed:0.15 green:0.15 blue:0.16 alpha:1.0];
}

- (UIColor *)surfaceAlt {
    // Xám hover/element (#2D2D30)
    return [UIColor colorWithRed:0.18 green:0.18 blue:0.19 alpha:1.0];
}

- (UIColor *)border {
    // Viền mảnh sắc nét (#3F3F46)
    return [UIColor colorWithRed:0.25 green:0.25 blue:0.27 alpha:1.0];
}

- (UIColor *)textPrimary {
    // Trắng sáng tiêu chuẩn (#D4D4D4)
    return [UIColor colorWithRed:0.83 green:0.83 blue:0.83 alpha:1.0];
}

- (UIColor *)textMuted {
    // Xám chữ phụ (#858585)
    return [UIColor colorWithRed:0.52 green:0.52 blue:0.52 alpha:1.0];
}

- (UIColor *)accent {
    // Xanh lá ImGui Accent sắc nét (#00E676)
    return [UIColor colorWithRed:0.00 green:0.90 blue:0.46 alpha:1.0];
}

- (UIFont *)monoFont:(CGFloat)size {
    return [UIFont fontWithName:@"Menlo" size:size] ?: [UIFont systemFontOfSize:size];
}

- (UIFont *)monoBoldFont:(CGFloat)size {
    return [UIFont fontWithName:@"Menlo-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size];
}

@end
