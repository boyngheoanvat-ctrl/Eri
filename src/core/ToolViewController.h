#import <UIKit/UIKit.h>

@class LuaVC;

@interface ToolViewController : UIViewController
- (void)selectTab:(NSInteger)index;
- (void)reload;
@property (nonatomic, strong, readonly) LuaVC *luaVC;
@end
