#import <UIKit/UIKit.h>
#import "ToolTheme.h"

@interface CHookVC : UIViewController

@property (nonatomic, strong) UITextView *codeTextView;
@property (nonatomic, strong) UITextView *consoleTextView;
@property (nonatomic, strong) UISegmentedControl *templateSegment;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) NSMutableString *consoleLog;

- (void)reload;
- (void)setupUI;
- (void)updateCodeTemplateForIndex:(NSInteger)index;

@end
