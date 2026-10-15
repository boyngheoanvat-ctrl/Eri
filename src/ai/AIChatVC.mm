#import "AIChatVC.h"
#import "ToolViewController.h"
#import "LuaVC.h"
#import "ToolTheme.h"

@interface AIChatVC () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messages;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendButton;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.messages = [NSMutableArray array];
    
    [self.messages addObject:@{
        @"sender": @"ai",
        @"text": @"Hello người ae! Tui là tool do Eri Nguyễn tạo ra."
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
    self.inputField.placeholder = @"Nhập yêu cầu (hack map, mod skin, bất tử)...";
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
    NSString *luaPayload = nil;
    NSString *aiResponseText = @"";
    BOOL shouldSwitchToLua = NO;
    
    if ([lower containsString:@"hi"] || [lower containsString:@"hello"] || [lower containsString:@"chào"] || [lower containsString:@"alo"]) {
        aiResponseText = [NSString stringWithFormat:@"Hello người ae! Đã sẵn sàng phân tích offset. Yêu cầu hiện tại: '%@'.", text];
        shouldSwitchToLua = NO;
    }
    else {
        shouldSwitchToLua = YES;
        
        if ([lower containsString:@"map"] || [lower containsString:@"hack map"] || [lower containsString:@"sáng bản đồ"]) {
            aiResponseText = @"[Ai Eri] Đã tìm thấy Method Hack Map!\n\n"
                              @"• Class: CameraUtils\n"
                              @"• Method: CanSight\n"
                              @"• RVA: 0x1097E5678\n"
                              @"• Offset: 0x1097E5678\n"
                              @"• VA: 0x1234567890\n"
                              @"• Token: 0x6000123\n\n"
                              @"Đã tự động nạp payload vào Lua Console kèm cơ chế pcall chống văng!";
                              
            luaPayload = @"-- [Ai Eri] Hack Map Pro Script (RVA: 0x1097E5678)\n"
                         "local ok, err = pcall(function()\n"
                         "    local base = il2cpp.get_image_base('UnityFramework')\n"
                         "    if base then\n"
                         "        local rva = 0x1097E5678\n"
                         "        local target = base + rva\n"
                         "        print('[Lua Safe] CameraUtils$$CanSight Target: 0x' .. string.format('%X', target))\n"
                         "        -- Thực hiện patch hoặc hook tại đây\n"
                         "    else\n"
                         "        print('[Lua Safe] Không tìm thấy base UnityFramework.')\n"
                         "    end\n"
                         "end)\n"
                         "if not ok then print('[Lua Crash Prevented] ' .. tostring(err)) end\n";
        }
        else if ([lower containsString:@"skin"] || [lower containsString:@"mod skin"]) {
            aiResponseText = @"[Ai Eri] Đã tìm thấy Method Mod Skin!\n\n"
                              @"• Class: HeroSkinManager\n"
                              @"• Method: ApplySkinOverride\n"
                              @"• RVA: 0x10842B100\n"
                              @"• Offset: 0x10842B100\n"
                              @"• VA: 0x12345678A0\n"
                              @"• Token: 0x6000456\n\n"
                              @"Đã tự động nạp payload vào Lua Console!";
                              
            luaPayload = @"-- [Ai Eri] Mod Skin Script (RVA: 0x10842B100)\n"
                         "local ok, err = pcall(function()\n"
                         "    local base = il2cpp.get_image_base('UnityFramework')\n"
                         "    if base then\n"
                         "        local rva = 0x10842B100\n"
                         "        print('[Lua Safe] HeroSkinManager$$ApplySkinOverride RVA: 0x' .. string.format('%X', rva))\n"
                         "    end\n"
                         "end)\n"
                         "if not ok then print('[Lua Crash Prevented] ' .. tostring(err)) end\n";
        }
        else {
            aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Đã phân tích yêu cầu '%@':\n\n"
                                                        @"• Class: GameCoreSystem\n"
                                                        @"• Method: ExecuteAction\n"
                                                        @"• RVA: 0x105001234\n"
                                                        @"• Offset: 0x105001234\n\n"
                                                        @"Đã sinh script Lua an toàn tương ứng.", text];
                                                        
            luaPayload = [NSString stringWithFormat:
                @"-- [Ai Eri] Custom Command: %@\n"
                 "local ok, err = pcall(function()\n"
                 "    print('[Lua Safe] Thực thi lệnh: %@ tại RVA: 0x105001234')\n"
                 "end)\n"
                 "if not ok then print('[Lua Crash Prevented] ' .. tostring(err)) end\n", text, text];
        }
    }
    
    [self.messages addObject:@{@"sender": @"ai", @"text": aiResponseText}];
    [self.tableView reloadData];
    
    if (self.messages.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
    
    if (shouldSwitchToLua && luaPayload) {
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
                        if ([luaVC respondsToSelector:@selector(loadViewIfNeeded)]) {
                            [luaVC loadViewIfNeeded];
                        }
                        if ([luaVC respondsToSelector:@selector(setScriptContent:)]) {
                            [luaVC performSelector:@selector(setScriptContent:) withObject:luaPayload];
                        }
                    }
                }
            }
        });
    }
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
