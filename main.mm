#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "substrate.h"

// Biến lưu trạng thái các tính năng Mod
static BOOL autoArrowOn = NO;
static BOOL taikoModeOn = NO;
static BOOL fullMiniGameOn = NO;

// 1. Hàm thực thi logic hack ngầm liên tục mỗi frame
static void executeModLogic() {
    if (autoArrowOn) {
        // Code xử lý Auto Arrow / Perfect
    }
    if (taikoModeOn) {
        // Code xử lý Taiko Mode
    }
    if (fullMiniGameOn) {
        // Code xử lý Full Mini Game & Fix Crazy Score
    }
}

// 2. Vòng lặp chạy ngầm gọi logic ~30 lần/giây
static void startModLoop() {
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), 0.033 * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        executeModLogic();
    });
    dispatch_resume(timer);
}

// 3. Menu UIKit thay thế ImGui (Chạy trực tiếp 100% ổn định trên mọi phiên bản iOS/Game mà không sợ lỗi Context ImGui)
@interface AutoDanceMenuController : NSObject
+ * (void)showMenu;
@end

@implementation AutoDanceMenuController

+ (void)showMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) { window = w; break; }
                }
            }
        }
        if (!window) return;
        UIViewController *rootVC = window.rootViewController;
        while (rootVC.presentedViewController) { rootVC = rootVC.presentedViewController; }

        // Tạo giao diện Checkbox Switch mượt mà
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AutoDance Hex v7.2"
                                                                     message:@"Bật/Tắt tính năng trực tiếp:"
                                                              preferredStyle:UIAlertControllerStyleAlert];

        // Checkbox Auto Arrow
        [alert addAction:[UIAlertAction actionWithTitle:autoArrowOn ? @"[ ✅ ] Auto Arrow: BẬT" : @"[ ❌ ] Auto Arrow: TẮT" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            autoArrowOn = !autoArrowOn;
            [self showToast:autoArrowOn ? @"Đã Bật Auto Arrow" : @"Đã Tắt Auto Arrow"];
        }]];

        // Checkbox Taiko Mode
        [alert addAction:[UIAlertAction actionWithTitle:taikoModeOn ? @"[ ✅ ] Taiko Mode: BẬT" : @"[ ❌ ] Taiko Mode: TẮT" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            taikoModeOn = !taikoModeOn;
            [self showToast:taikoModeOn ? @"Đã Bật Taiko Mode" : @"Đã Tắt Taiko Mode"];
        }]];

        // Checkbox Full Mini Game
        [alert addAction:[UIAlertAction actionWithTitle:fullMiniGameOn ? @"[ ✅ ] Full Mini Game: BẬT" : @"[ ❌ ] Full Mini Game: TẮT" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            fullMiniGameOn = !fullMiniGameOn;
            [self showToast:fullMiniGameOn ? @"Đã Bật Full Mini Game" : @"Đã Tắt Full Mini Game"];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng Menu" style:UIAlertActionStyleCancel handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)showToast:(NSString *)msg {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(50, window.frame.size.height - 140, window.frame.size.width - 100, 40)];
    toast.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.85];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont boldSystemFontOfSize:14];
    toast.text = msg;
    toast.layer.cornerRadius = 10;
    toast.clipsToBounds = YES;
    [window addSubview:toast];
    [UIView animateWithDuration:2.0 animations:^{ toast.alpha = 0.0; } completion:^(BOOL finished) { [toast removeFromSuperview]; }];
}

@end

// 4. Bắt sự kiện chạm 2 ngón tay mở Menu
@interface MenuGestureListener : NSObject
@end
@implementation MenuGestureListener
+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (window) {
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            tap.numberOfTouchesRequired = 2; // Chạm 2 ngón tay
            [window addGestureRecognizer:tap];
            startModLoop();
            NSLog(@"[AutoDanceHex] Khởi chạy thành công toàn bộ hệ thống!");
        }
    });
}
+ (void)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [AutoDanceMenuController showMenu];
    }
}
@end

