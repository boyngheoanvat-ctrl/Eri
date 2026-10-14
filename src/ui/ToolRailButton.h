#import <UIKit/UIKit.h>

@interface ToolRailButton : UIControl

@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) BOOL active;

- (instancetype)initWithTitle:(NSString *)title symbol:(NSString *)symbol;

@end
