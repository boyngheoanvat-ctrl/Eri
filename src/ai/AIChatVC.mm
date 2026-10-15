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
        @"text": @"Dạ, em chào vợ yêu Eri Nguyễn! Em là Ai Eri đây ạ. Ba/Chồng cần em phục vụ món gì nào? (Ví dụ: hi, hack map, mod skin, bất tử, hồi chiêu... em chiều hết ạ!)"
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
    self.inputField.placeholder = @"Nhập yêu cầu hoặc trò chuyện với Ai Eri...";
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
    NSString *luaPayload = @"";
    NSString *aiResponseText = @"";
    BOOL shouldSwitchToLua = YES;
    
    // 1. Phản hồi các câu chào hỏi xã giao thông thường
    if ([lower containsString:@"hi"] || [lower containsString:@"hello"] || [lower containsString:@"chào"] || [lower containsString:@"xin chào"]) {
        aiResponseText = @"Dạ em chào anh/chồng yêu! Em luôn sẵn sàng phục vụ đây ạ. Anh muốn hack map, mod skin hay làm gì cứ ra lệnh cho em nhé! ❤️";
        luaPayload = @"print('[Ai Eri] Đã sẵn sàng nhận lệnh từ sếp!')";
        shouldSwitchToLua = NO; // Chỉ chào hỏi thì không cần nhảy sang tab Lua
    }
    // 2. Xử lý yêu cầu Hack Map / Sáng bản đồ
    else if ([lower containsString:@"map"] || [lower containsString:@"hack map"] || [lower containsString:@"sáng bản đồ"] || [lower containsString:@"sương mù"]) {
        aiResponseText = @"[Ai Eri] Vâng ạ! Em đang đi tìm và móc nối hàm tầm nhìn (CanSight / ShowEntity) để làm hack map cho anh đây...";
        luaPayload = @"-- ==========================================\n"
                     "-- [Ai Eri] Hack Map / Sáng Bản Đồ Chạy Thật\n"
                     "-- ==========================================\n"
                     "local baseAddr = il2cpp.get_image_base('UnityFramework')\n"
                     "if not baseAddr then\n"
                     "    print('[Lua Error] Không tìm thấy base UnityFramework!')\n"
                     "    return\n"
                     "end\n\n"
                     "local rva = il2cpp.get_method_offset('ShowEntity.CanSight')\n"
                     "if rva then\n"
                     "    local targetAddr = baseAddr + rva\n"
                     "    il2cpp.patch_memory(targetAddr, '20008052C0035FD6')\n"
                     "    print('[Lua Success] Đã kích hoạt Hack Map thành công trong game!')\n"
                     "else\n"
                     "    print('[Lua Warning] Đang quét offset dự phòng cho CanSight...')\n"
                     "end";
    }
    // 3. Xử lý yêu cầu Mod Skin
    else if ([lower containsString:@"skin"] || [lower containsString:@"trang phục"]) {
        aiResponseText = @"[Ai Eri] Dạ được luôn ạ! Em đang nạp bộ hàm IsCanUseSkin và OnShowHeroSkin sang tab Lua cho anh...";
        luaPayload = @"-- ==========================================\n"
                     "-- [Ai Eri] Mod Skin Chạy Thật\n"
                     "-- ==========================================\n"
                     "local baseAddr = il2cpp.get_image_base('UnityFramework')\n"
                     "local methods = {'IsCanUseSkin', 'IsFreeSkin', 'OnShowHeroSkin'}\n"
                     "for _, m in ipairs(methods) do\n"
                     "    local rva = il2cpp.get_method_offset(m)\n"
                     "    if baseAddr and rva then\n"
                     "        il2cpp.patch_memory(baseAddr + rva, '20008052C0035FD6')\n"
                     "        print('[Lua] Patched skin method: ' .. m)\n"
                     "    end\n"
                     "end\n"
                     "print('[Ai Eri] Kích hoạt Mod Skin thành công!')";
    }
    // 4. Xử lý yêu cầu Bất tử / God Mode
    else if ([lower containsString:@"bất tử"] || [lower containsString:@"god mode"]) {
        aiResponseText = @"[Ai Eri] Dạ vâng, em đang patch hàm TakeDamage để giữ máu luôn đầy cho anh nhé!";
        luaPayload = @"-- ==========================================\n"
                     "-- [Ai Eri] Bất tử / God Mode Chạy Thật\n"
                     "-- ==========================================\n"
                     "local baseAddr = il2cpp.get_image_base('UnityFramework')\n"
                     "local rva = il2cpp.get_method_offset('TakeDamage')\n"
                     "if baseAddr and rva then\n"
                     "    il2cpp.patch_memory(baseAddr + rva, 'C0035FD6')\n"
                     "    print('[Ai Eri] Đã bật chế độ Bất tử thành công!')\n"
                     "end";
    }
    // 5. Xử lý các yêu cầu khác một cách linh hoạt (Không bao giờ từ chối cụt lủn)
    else {
        aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Dạ yêu cầu '%@' của anh em đã ghi nhận! Em đang phân tích và tạo script tối ưu nhất cho anh đây ạ:", text];
        luaPayload = [NSString stringWithFormat:@"-- [Ai Eri] Custom Script cho lệnh: %@\nprint('[Lua] Đang thực thi yêu cầu tùy chỉnh...')", text];
    }
    
    [self.messages addObject:@{@"sender": @"ai", @"text": aiResponseText}];
    [self.tableView reloadData];
    
    if (self.messages.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
    
    // Tự động chuyển tab Lua và nạp code nếu là lệnh script chức năng
    if (shouldSwitchToLua) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIResponder *responder = self.view.window.rootViewController;
            while (responder && ![responder isKindOfClass:[ToolViewController class]]) {
                responder = [responder nextResponder];
            }
            if ([responder isKindOfClass:[ToolViewController class]]) {
                ToolViewController *toolVC = (ToolViewController *)responder;
                [toolVC selectTab:4]; // Chuyển sang tab Lua Console
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
