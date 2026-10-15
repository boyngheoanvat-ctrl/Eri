#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ToolTheme : NSObject

+ (instancetype)shared;

// Background
- (UIColor *)background;
- (UIColor *)surface;
- (UIColor *)surfaceAlt;
 
// Text
- (UIColor *)textPrimary;
- (UIColor *)textSecondary;
- (UIColor *)textMuted;

// Accent
- (UIColor *)accent;
- (UIColor *)accentSoft;
- (UIColor *)success;
- (UIColor *)warning;
- (UIColor *)danger;

// UI Elements
- (UIColor *)divider;
- (UIColor *)border;
- (UIColor *)selectedFill;
- (UIColor *)mutedFill;

// Fonts
- (UIFont *)monoFont:(CGFloat)size;
- (UIFont *)monoBoldFont:(CGFloat)size;

@end
