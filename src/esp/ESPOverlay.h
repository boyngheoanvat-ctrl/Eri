#import <UIKit/UIKit.h>

@interface ESPOverlay : UIView

+ (instancetype)shared;
- (void)attachToWindow:(UIWindow *)window;
- (void)show;
- (void)hide;
- (void)toggle;
- (void)reload;

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL showHP;
@property (nonatomic, assign) BOOL showName;
@property (nonatomic, assign) BOOL showDistance;
@property (nonatomic, assign) BOOL showBox;
@property (nonatomic, assign) BOOL showLine;

@end
