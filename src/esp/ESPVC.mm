#import "ESPVC.h"
#import "ToolTheme.h"

@implementation ESPVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
}
- (void)reload {}
@end
