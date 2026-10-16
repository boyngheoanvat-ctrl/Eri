#import "MethodCallerVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@implementation MethodCallerVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
}
- (void)reload {}
@end
