//
//  ImGuiDrawView.h
//  ImGuiTest
//
//  Created by yiming on 2021/6/2.
//

#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImGuiDrawView : UIViewController <MTKViewDelegate>

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> cmdQueue;

+ (void)showMenu:(BOOL)open;
+ (void)showChange:(BOOL)open;

@end

NS_ASSUME_NONNULL_END
