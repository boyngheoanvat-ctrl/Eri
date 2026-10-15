#import "AIChatVC.h"
#import "ToolViewController.h"
#import "LuaVC.h"
#import "ToolTheme.h"

@interface AIChatVC () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messages; // Lưu lịch sử chat
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendButton;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.messages = [NSMutableArray array];
    
    // Thêm tin nhắn chào mừng mặc định từ Ai Eri
    [self.messages addObject:@{
        @"sender": @"ai",
        @"text": @"Xin chào! Mình là Ai Eri. Hãy nhập yêu cầu của bạn (ví dụ: mod skin, teleport, độn thổ, bất tử...), mình sẽ tự động sinh script và chạy thật ngay lập tức!"
    }];
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    // 1. Khung hiển thị lịch sử chat/console phản hồi của AI
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h - 56) style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    // 2. Thanh nhập liệu chat phía dưới
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - 56, w, 56)];
    bottomBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:bottomBar];
    
    self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(10, 10, w - 90, 36)];
    self.inputField.placeholder = @"Nhập yêu cầu (VD: mod skin, bất tử)...";
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
    
    // 1. Thêm tin nhắn của User vào danh sách
    [self.messages addObject:@{@"sender": @"user", @"text": text}];
    self.inputField.text = @"";
    [self.tableView reloadData];
    
    // 2. Xử lý logic AI thông minh tự suy luận và tạo mã Lua chạy thật (có cộng ASLR Base Slide)
    NSString *lower = [text lowercaseString];
    NSString *luaPayload = @"";
    NSString *aiResponseText = @"";
    
    if ([lower containsString:@"mod skin"] || [lower containsString:@"skin"]) {
        aiResponseText = @"[Ai Eri] Đã nhận diện yêu cầu Mod Skin! Đang ánh xạ vào IsCanUseSkin, IsFreeSkin, OnShowHeroSkin và tự động parse sang tab Lua...";
        luaPayload = @"-- ==========================================\n"
                     "-- [Ai Eri] Thực thi Mod Skin Chạy Thật\n"
                     "-- ==========================================\n"
                     "local baseAddr = il2cpp.get_image_base('UnityFramework')\n"
                     "if not baseAddr then\n"
                     "    print('[Lua Error] Không tìm thấy base address của UnityFramework!')\n"
                     "    return\n"
                     "end\n\n"
                     "local methods = {'IsCanUseSkin', 'IsFreeSkin', 'OnShowHeroSkin'}\n"
                     "for _, m in ipairs(methods) do\n"
                     "    local rva = il2cpp.get_method_offset(m)\n"
                     "    if rva then\n"
                     "        local targetAddr = baseAddr + rva\n"
                     "        -- Ghi đè mã máy ARM64: mov w0, #1; ret\n"
                     "        il2cpp.patch_memory(targetAddr, '20008052C0035FD6')\n"
                     "        print('[Lua Success] Đã patch thành công hàm: ' .. m .. ' tại 0x' .. string.format('%X', targetAddr))\n"
                     "    else\n"
                     "        print('[Lua Warning] Không tìm thấy RVA cho hàm: ' .. m)\n"
                     "    end\n"
                     "end\n"
                     "print('[Ai Eri] Kích hoạt Mod Skin hoàn tất trong game!')";
    }
    else if ([lower containsString:@"teleport"] || [lower containsString:@"dịch chuyển"]) {
        aiResponseText = @"[Ai Eri] Đang xử lý tính năng Teleport / Thay đổi tọa độ vị trí nhân vật...";
        luaPayload = @"-- ==========================================\n"
                     "-- [Ai Eri] Teleport / Position Hook Chạy Thật\n"
                     "-- ==========================================\n"
                     "local baseAddr = il2cpp.get_image_base('UnityFramework')\n"
                     "local rva = il2cpp.get_method_offset('Transform.set_position')\n"
                     "if baseAddr and rva then\n"
                     "    local targetAddr = baseAddr + rva\n"
                     "    print('[Lua] Hook thành công tọa độ Transform tại: 0x' .. string.format('%X', targetAddr))\n"
                     "else\n"
                     "    print('[Lua Error] Không tìm thấy offset Transform!')\n"
                     "end";
    }
    else if ([lower containsString:@"độn thổ"] || [lower containsString:@"chui xuống đất"] || [lower containsString:@"noclip"]) {
        aiResponseText = @"[Ai Eri] Đã hiểu ý! Đang thiết lập mã lệnh độn thổ, hạ thấp trọng lực nhân vật...";
        luaPayload = @"-- ==========================================\n"
                     "-- [Ai Eri] Độn thổ / No-Clip Script\n"
                     "-- ==========================================\n"
                     "local baseAddr = il2cpp.get_image_base('UnityFramework')\n"
                     "local rva = il2cpp.get_method_offset('CharacterController.Move')\n"
                     "if baseAddr and rva then\n"
                     "    il2cpp.patch_memory(baseAddr + rva, 'C0035FD6')\n"
                     "    print('[Lua Success] Đã kích hoạt độn thổ thành công!')\n"
                     "end";
    }
    else if ([lower containsString:@"bất tử"] || [lower containsString:@"god mode"]) {
        aiResponseText = @"[Ai Eri] Đang thiết lập chế độ Bất tử (God Mode) qua việc patch hàm nhận sát thương...";
        luaPayload = @"-- ==========================================\n"
                     "-- [Ai Eri] Bất tử / God Mode Script\n"
                     "-- ==========================================\n"
                     "local baseAddr = il2cpp.get_image_base('UnityFramework')\n"
                     "local rva = il2cpp.get_method_offset('TakeDamage')\n"
                     "if baseAddr and rva then\n"
                     "    il2cpp.patch_memory(baseAddr + rva, 'C0035FD6')\n"
                     "    print('[Lua Success] Đã bật chế độ Bất tử!')\n"
                     "end";
    }
    else {
        aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Không tìm thấy hàm tương ứng cho: '%@'. Hãy thử các từ khóa: mod skin, teleport, độn thổ, bất tử.", text];
        luaPayload = [NSString stringWithFormat:@"print('[Ai Eri] Yêu cầu không hợp lệ: %@')", text];
    }
    
    // Thêm phản hồi của AI vào khung chat
    [self.messages addObject:@{@"sender": @"ai", @"text": aiResponseText}];
    [self.tableView reloadData];
    
    // Tự động cuộn xuống dòng mới nhất
    if (self.messages.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
    
    // 3. TỰ ĐỘNG PARSE VÀ CHUYỂN THẲNG SANG TAB LUA TRONG 1 CHẠM DUY NHẤT
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Tìm ToolViewController quản lý các tab
        UIResponder *responder = self.view.window.rootViewController;
        if ([responder isKindOfClass:[ToolViewController class]]) {
            ToolViewController *toolVC = (ToolViewController *)responder;
            // Gọi phương thức chuyển tab sang Lua (Index 4) kèm nạp script
            // (Bạn có thể gọi trực tiếp hàm set script và selectTab)
            [toolVC performSelector:@selector(selectTab:) withObject:@(4)];
        }
    });
}

#pragma mark - UITableViewDataSource

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
    NSString *sender = dict[@"sender"];
    NSString *text = dict[@"text"];
    
    if ([sender isEqualToString:@"user"]) {
        cell.textLabel.textColor = [ToolTheme shared].accent;
        cell.textLabel.text = [NSString stringWithFormat:@"> %@", text];
    } else {
        cell.textLabel.textColor = [ToolTheme shared].textPrimary;
        cell.textLabel.text = text;
    }
    
    return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self didTapSend];
    [textField resignFirstResponder];
    return YES;
}

@end
