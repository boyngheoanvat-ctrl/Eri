#import <UIKit/UIKit.h>

@interface ToolWindow : UIWindow

+ (instancetype)shared;
- (void)show;
- (void)hide;
- (void)toggle;

@end
