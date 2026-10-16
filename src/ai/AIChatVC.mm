#import "AIChatVC.h"
#import "ToolViewController.h"
#import "LuaVC.h"
#import "ToolTheme.h"
#include <dlfcn.h>

@interface AIChatVC () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong, nonnull) NSMutableArray<NSDictionary *> *messages;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendButton;

// Danh sách lưu các tính năng đã được yêu cầu tích lũy
@property (nonatomic, strong) NSMutableSet<NSString *> *activeModules;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.messages = [NSMutableArray array];
    self.activeModules = [NSMutableSet set];
    
    [self.messages addObject:@{
        @"sender": @"ai",
        @"text": @"Hello người ae! AI Eri đã sẵn sàng tích lũy tính năng hoặc gom nhóm thông minh theo yêu cầu."
    }];
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h - 56) style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - 56, w, 56)];
    bottomBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:bottomBar];
    
    self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(10, 10, w - 90, 36)];
    self.inputField.placeholder = @"Nhập yêu cầu (hack map, camera xa, mod skin)...";
    self.inputField.backgroundColor = [ToolTheme shared].surface;
    self.inputField.textColor = [ToolTheme shared].textPrimary;
    self.inputField.font = [[ToolTheme shared] monoFont:12];
    self.inputField.layer.cornerRadius = 4;
    self.inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.inputField.leftViewMode = UITextFieldViewModeAlways;
    self.inputField.delegate = self;
    self.inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [bottomBar addSubview:self.inputField];
    
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(w - 75, 10, 65, 36);
    self.sendButton.backgroundColor = [ToolTheme shared].accent;
    [self.sendButton setTitle:@"Gửi" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.sendButton.layer.cornerRadius = 4;
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton addTarget:self action:@selector(didTapSend) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.sendButton];
}

- (void)reload {
    [self.tableView reloadData];
}

- (void)didTapSend {
    NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    [self.messages addObject:@{@"sender": @"user", @"text": text}];
    self.inputField.text = @"";
    [self.tableView reloadData];
    
    NSString *lower = [text lowercaseString];
    NSString *detectedKey = @"custom";
    
    // Phân loại từ khóa thông minh
    if ([lower containsString:@"map"] || [lower containsString:@"sáng bản đồ"]) {
        detectedKey = @"hack_map";
    } else if ([lower containsString:@"camera"] || [lower containsString:@"xa"]) {
        detectedKey = @"camera_xa";
    } else if ([lower containsString:@"skin"] || [lower containsString:@"trang phục"]) {
        detectedKey = @"mod_skin";
    } else if ([lower containsString:@"bất tử"] || [lower containsString:@"god"]) {
        detectedKey = @"god_mode";
    }
    
    // Kiểm tra xem tính năng này đã tồn tại chưa (Tránh lặp lại nếu chat trùng ý)
    BOOL isDuplicate = [self.activeModules containsObject:detectedKey];
    if (!isDuplicate && ![detectedKey isEqualToString:@"custom"]) {
        [self.activeModules addObject:detectedKey];
    }
    
    NSString *aiResponseText = @"";
    if (isDuplicate) {
        aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Tính năng này đã có sẵn trong danh sách menu hiện tại. Không tạo bản sao trùng lặp cho: '%@'.", text];
    } else {
        aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Đã tích hợp thành công vào menu tổng hợp!\n• Tổng số tính năng đang hoạt động: %lu\n• Yêu cầu mới: %@", (unsigned long)self.activeModules.count, text];
    }
    
    // Sinh Script Lua tổng hợp dựa trên toàn bộ các module đang được kích hoạt tích lũy
    NSMutableString *luaPayload = [NSMutableString stringWithFormat:
        @"-- [Ai Eri] Integrated Script Menu (Active Modules: %lu)\n"
         "local ok, err = pcall(function()\n"
         "    print('[Lua Safe] Khởi chạy menu tổng hợp...')\n", (unsigned long)self.activeModules.count];
         
    for (NSString *mod in self.activeModules) {
        if ([mod isEqualToString:@"hack_map"]) {
            [luaPayload appendString:@"    print('[Mod] Kích hoạt Hack Map (CameraUtils$$CanSight)')\n"];
        } else if ([mod isEqualToString:@"camera_xa"]) {
            [luaPayload appendString:@"    print('[Mod] Kích hoạt Camera Xa (CameraController$$Update)')\n"];
        } else if ([mod isEqualToString:@"mod_skin"]) {
            [luaPayload appendString:@"    print('[Mod] Kích hoạt Mod Skin (HeroSkinManager)')\n"];
        } else if ([mod isEqualToString:@"god_mode"]) {
            [luaPayload appendString:@"    print('[Mod] Kích hoạt Bất Tử (PlayerHealth$$TakeDamage)')\n"];
        }
    }
    [luaPayload appendString:@"end)\nif not ok then print('[Lua Crash Prevented] ' .. tostring(err)) end\n"];
    
    [self.messages addObject:@{@"sender": @"ai", @"text": aiResponseText}];
    [self.tableView reloadData];
    
    if (self.messages.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
    
    // Tự động đẩy payload tổng hợp sang tab Lua
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIResponder *responder = self.view.window.rootViewController;
        ToolViewController *targetToolVC = nil;
        
        if ([responder isKindOfClass:[ToolViewController class]]) {
            targetToolVC = (ToolViewController *)responder;
        } else if ([responder isKindOfClass:[UIViewController class]]) {
            for (UIViewController *child in ((UIViewController *)responder).childViewControllers) {
                if ([child isKindOfClass:[ToolViewController class]]) {
                    targetToolVC = (ToolViewController *)child;
                    break;
                }
            }
        }
        
        if (targetToolVC) {
            [targetToolVC selectTab:4];
            if ([targetToolVC respondsToSelector:@selector(luaVC)]) {
                id luaVC = [targetToolVC valueForKey:@"luaVC"];
                if (luaVC) {
                    if ([luaVC respondsToSelector:@selector(loadViewIfNeeded)]) [luaVC loadViewIfNeeded];
                    if ([luaVC respondsToSelector:@selector(setScriptContent:)]) {
                        [luaVC performSelector:@selector(setScriptContent:) withObject:luaPayload];
                    }
                }
            }
        }
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellID = @"AIChatCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellID];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [[ToolTheme shared] monoFont:11];
    }
    NSDictionary *dict = self.messages[indexPath.row];
    if ([dict[@"sender"] isEqualToString:@"user"]) {
        cell.textLabel.textColor = [ToolTheme shared].accent;
        cell.textLabel.text = [NSString stringWithFormat:@"> %@", dict[@"text"]];
    } else {
        cell.textLabel.textColor = [ToolTheme shared].textPrimary;
        cell.textLabel.text = dict[@"text"];
    }
    return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self didTapSend];
    [textField resignFirstResponder];
    return YES;
}

@end
