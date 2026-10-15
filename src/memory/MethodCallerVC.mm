#import "MethodCallerVC.h"
#import "ToolTheme.h"

@interface MethodCallerVC ()
@property (nonatomic, strong) UIButton *callButton;
@end

@implementation MethodCallerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    
    self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.callButton.frame = CGRectMake(16, 170, w - 32, 44);
    self.callButton.backgroundColor = [ToolTheme shared].accent;
    [self.callButton setTitle:@"Call Method" forState:UIControlStateNormal];
    [self.callButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.callButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:13];
    self.callButton.layer.cornerRadius = 6;
    self.callButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.callButton];
}

- (void)reload {
}

@end
