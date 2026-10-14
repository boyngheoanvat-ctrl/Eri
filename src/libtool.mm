#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ToolWindow.h"
#import "ToolGestureManager.h"

__attribute__((constructor))
static void libtool_init(void) {
    NSLog(@"[ToolKit] loaded");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // Tạo ToolWindow trước
        [ToolWindow shared];

        // Gắn gesture vào key window
        UIWindow *kw = nil;
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.isKeyWindow && ![w isKindOfClass:[ToolWindow class]]) {
                kw = w;
                break;
            }
        }

        if (!kw) {
            for (UIWindow *w in UIApplication.sharedApplication.windows) {
                if (![w isKindOfClass:[ToolWindow class]]) {
                    kw = w;
                    break;
                }
            }
        }

        if (kw) {
            [[ToolGestureManager shared] attachToWindow:kw];
            NSLog(@"[ToolKit] Gesture attached to %@", kw);
        } else {
            NSLog(@"[ToolKit] No key window found");
        }
    });
}
