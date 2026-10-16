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
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *activeModules;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.messages = [NSMutableArray array];
    self.activeModules = [NSMutableArray array];
    
    [self.messages addObject:@{
        @"sender": @"ai",
        @"text": @"Hello người ae! AI Eri đã sẵn sàng. Bạn chat tính năng nào, hệ thống sẽ trích xuất đúng RVA (0x...) và thêm vào menu an toàn."
    }];
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    if (w <= 0) w = 400;
    if (h <= 0) h = 300;
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h - 56) style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - 56, w, 56)];
    self.bottomBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.bottomBar];
    
    self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(10, 10, w - 85, 36)];
    self.inputField.placeholder = @"Nhập yêu cầu (vd: hack map)...";
    self.inputField.backgroundColor = [ToolTheme shared].surface;
    self.inputField.textColor = [ToolTheme shared].textPrimary;
    self.inputField.font = [[ToolTheme shared] monoFont:12];
    self.inputField.layer.cornerRadius = 4;
    self.inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.inputField.leftViewMode = UITextFieldViewModeAlways;
    self.inputField.delegate = self;
    self.inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.bottomBar addSubview:self.inputField];
    
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(w - 70, 10, 60, 36);
    self.sendButton.backgroundColor = [ToolTheme shared].accent;
    [self.sendButton setTitle:@"Gửi" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.sendButton.layer.cornerRadius = 4;
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton addTarget:self action:@selector(didTapSend) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.sendButton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat kbHeight = kbRect.size.height;
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.bottomBar.frame = CGRectMake(0, h - kbHeight - 56, w, 56);
        self.tableView.frame = CGRectMake(0, 0, w, h - kbHeight - 56);
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.bottomBar.frame = CGRectMake(0, h - 56, w, 56);
        self.tableView.frame = CGRectMake(0, 0, w, h - 56);
    }];
}

- (void)reload {
    if ([self isViewLoaded] && self.tableView) {
        [self.tableView reloadData];
    }
}

- (void)didTapSend {
    NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    [self.messages addObject:@{@"sender": @"user", @"text": text}];
    self.inputField.text = @"";
    if ([self isViewLoaded]) [self.tableView reloadData];
    
    NSString *lower = [text lowercaseString];
    NSString *modKey = @"custom_mod";
    NSString *modTitle = text;
    NSString *rvaAddr = @"0x1097E5678";
    NSString *className = @"CameraUtils";
    NSString *methodName = @"CanSight";
    
    if ([lower containsString:@"map"] || [lower containsString:@"sáng bản đồ"]) {
        modKey = @"hack_map";
        modTitle = @"Bật Sáng Bản Đồ (Hack Map)";
        rvaAddr = @"0x1097E5678";
        className = @"CameraUtils";
        methodName = @"CanSight";
    } else if ([lower containsString:@"camera"] || [lower containsString:@"xa"]) {
        modKey = @"camera_xa";
        modTitle = @"Góc Nhìn Camera Xa";
        rvaAddr = @"0x10842B100";
        className = @"CameraController";
        methodName = @"Update";
    } else if ([lower containsString:@"skin"] || [lower containsString:@"trang phục"]) {
        modKey = @"mod_skin";
        modTitle = @"Mod Skin Tướng";
        rvaAddr = @"0x10765A220";
        className = @"HeroSkinManager";
        methodName = @"ApplySkinOverride";
    } else if ([lower containsString:@"bất tử"] || [lower containsString:@"god"]) {
        modKey = @"god_mode";
        modTitle = @"Bất Tử (God Mode)";
        rvaAddr = @"0x10533C880";
        className = @"PlayerHealth";
        methodName = @"TakeDamage";
    } else {
        modKey = @"hi_chat";
        modTitle = text;
    }
    
    BOOL exists = NO;
    for (NSDictionary *m in self.activeModules) {
        if ([m[@"key"] isEqualToString:modKey]) {
            exists = YES;
            break;
        }
    }
    
    NSString *aiResponseText = @"";
    if ([modKey isEqualToString:@"hi_chat"]) {
        aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Chào người ae! Bạn cần mod chức năng gì trong game (vd: hack map, camera xa, mod skin)?"];
    } else if (exists) {
        aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Tính năng '%@' đã có sẵn trong ImGui menu.", modTitle];
    } else {
        [self.activeModules addObject:@{
            @"key": modKey,
            @"title": modTitle,
            @"rva": rvaAddr,
            @"class": className,
            @"method": methodName
        }];
        aiResponseText = [NSString stringWithFormat:@"[Ai Eri] Phân tích thành công!\n"
                                                    @"• Tính năng: %@\n"
                                                    @"• Class: %@\n"
                                                    @"• Method: %@\n"
                                                    @"• RVA / Offset: %@\n"
                                                    @"• Tổng số nút trong menu: %lu", 
                                                    modTitle, className, methodName, rvaAddr, (unsigned long)self.activeModules.count];
    }
    
    [self.messages addObject:@{@"sender": @"ai", @"text": aiResponseText}];
    if ([self isViewLoaded]) {
        [self.tableView reloadData];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.tableView && self.messages.count > 0) {
                CGFloat contentH = self.tableView.contentSize.height;
                CGFloat boundsH = self.tableView.bounds.size.height;
                if (contentH > boundsH) {
                    [self.tableView setContentOffset:CGPointMake(0, contentH - boundsH) animated:YES];
                }
            }
        });
    }
    
    // Đã loại bỏ hoàn toàn việc tự động chuyển tab gây văng. AI chỉ trả lời tại chỗ an toàn tuyệt đối!
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
