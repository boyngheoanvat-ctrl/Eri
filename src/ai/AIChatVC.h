#import <UIKit/UIKit.h>

@protocol AIStreamDelegate <NSObject>
@optional
- (void)aiStreamDidReceiveText:(NSString *)text;
- (void)aiStreamDidFailWithError:(NSError *)error;
- (void)aiStreamDidComplete;
- (void)aiDidCallTool:(NSString *)toolName args:(NSDictionary *)args result:(id)result;
@end

@interface AIChatVC : UIViewController

- (void)reload;

@end
