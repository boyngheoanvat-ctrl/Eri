#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ToolGestureManager : NSObject

+ (instancetype)shared;
- (void)attachToWindow:(UIWindow *)window;

@end
