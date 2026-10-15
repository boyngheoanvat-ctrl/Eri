#import <UIKit/UIKit.h>
#import "ESPClassFinder.h"

@interface ESPOverlay : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL showHP;
@property (nonatomic, assign) BOOL showName;
@property (nonatomic, assign) BOOL showDistance;
@property (nonatomic, assign) BOOL showBox;
@property (nonatomic, assign) BOOL showLine;

// Bổ sung thuộc tính detectedTargets để ESPOverlayView truy xuất an toàn
@property (nonatomic, strong, readonly) NSArray<ESPTargetClass *> *detectedTargets;

+ (instancetype)shared;

- (void)attachToWindow:(UIWindow *)window;
- (void)show;
- (void)hide;
- (void)toggle;
- (void)reload;

@end
