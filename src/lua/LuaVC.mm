#import "LuaVC.h"
#import "ToolTheme.h"

@implementation LuaVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
}
- (void)reload {}
@end
