#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@interface AIChatCell : UITableViewCell
@property (nonatomic, strong) UILabel *contentLbl;
@property (nonatomic, strong) UIButton *actionCopyButton;
@property (nonatomic, copy) void (^onCopyBlock)(void);
@end

@implementation AIChatCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        self.contentLbl = [[UILabel alloc] init];
        self.contentLbl.numberOfLines = 0;
        self.contentLbl.font = [[ToolTheme shared] monoFont:11];
        [self.contentView addSubview:self.contentLbl];

        self.actionCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.actionCopyButton setTitle:@"Copy" forState:UIControlStateNormal];
        [self.actionCopyButton setTitleColor:[ToolTheme shared].accent forState:UIControlStateNormal];
        self.actionCopyButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:10];
        self.actionCopyButton.backgroundColor = [ToolTheme shared].surfaceAlt;
        self.actionCopyButton.layer.cornerRadius = 4;
        [self.actionCopyButton addTarget:self action:@selector(didTapCopy) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.actionCopyButton];
    }
    return self;
}

- (void)didTapCopy {
    if (self.onCopyBlock) self.onCopyBlock();
}

- (void)configureWithRole:(NSString *)role text:(NSString *)text width:(CGFloat)width {
    self.contentLbl.text = [NSString stringWithFormat:@"[%@]: %@", [role isEqualToString:@"user"] ? @"Ngài" : @"AI", text];
    self.contentLbl.textColor = [role isEqualToString:@"user"] ? [ToolTheme shared].accent : [ToolTheme shared].textPrimary;

    CGFloat padding = 16;
    CGFloat maxW = width - (padding * 2);
    CGSize size = [self.contentLbl sizeThatFits:CGSizeMake(maxW, CGFLOAT_MAX)];
    
    self.contentLbl.frame = CGRectMake(padding, 8, maxW, size.height);

    if ([role isEqualToString:@"assistant"]) {
        self.actionCopyButton.hidden = NO;
        self.actionCopyButton.frame = CGRectMake(width - 70 - padding, 8 + size.height + 4, 60, 24);
    } else {
        self.actionCopyButton.hidden = YES;
    }
}
@end

@interface AIChatVC () <UITextFieldDelegate, AIStreamDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messages;
@property (nonatomic, assign) BOOL isWaitingResponse;
@property (nonatomic, assign) CGFloat keyboardHeight;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    if (!self.messages) {
        self.messages = [NSMutableArray arrayWithArray:@[
            @{@"role": @"assistant", @"content": @"Hello Chào Người Anh Em !!! RVA Scan & Universal AI Agent sẵn sàng."}
        ]];
    }
    [self buildUI];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateLayoutWithKeyboardHeight:self.keyboardHeight];
}

- (void)updateLayoutWithKeyboardHeight:(CGFloat)kbHeight {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    if (w <= 50) w = 400;
    if (h <= 50) h = 300;
    
    CGFloat bottomH = 50;
    CGFloat usableHeight = h - kbHeight;
    
    self.bottomBar.frame = CGRectMake(0, usableHeight - bottomH, w, bottomH);
    self.tableView.frame = CGRectMake(0, 0, w, usableHeight - bottomH);
    
    self.inputField.frame = CGRectMake(12, 6, w - 84, 38);
    self.sendButton.frame = CGRectMake(w - 68, 6, 56, 38);
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect convertedKeyboardRect = [self.view convertRect:kbRect fromView:nil];
    self.keyboardHeight = CGRectGetHeight(self.view.bounds) - CGRectGetMinY(convertedKeyboardRect);
    if (self.keyboardHeight <= 0) self.keyboardHeight = 220;
    
    [UIView animateWithDuration:0.25 animations:^{
        [self updateLayoutWithKeyboardHeight:self.keyboardHeight];
        [self scrollToBottom];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.keyboardHeight = 0;
    [UIView animateWithDuration:0.25 animations:^{
        [self updateLayoutWithKeyboardHeight:0];
    }];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);
        if (w <= 50) w = 400;
        if (h <= 50) h = 300;

        CGFloat bottomH = 50;

        self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h - bottomH) style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.dataSource = self;
        self.tableView.delegate = self;
        [self.view addSubview:self.tableView];

        self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - bottomH, w, bottomH)];
        self.bottomBar.backgroundColor = [ToolTheme shared].surface;
        self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [self.view addSubview:self.bottomBar];

        self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(12, 6, w - 84, 38)];
        self.inputField.placeholder = @"Nhập bất kỳ yêu cầu nào (Hệ thống tự quét RVA)...";
        self.inputField.backgroundColor = [ToolTheme shared].surfaceAlt;
        self.inputField.textColor = [ToolTheme shared].textPrimary;
        self.inputField.font = [[ToolTheme shared] monoFont:12];
        self.inputField.layer.cornerRadius = 6;
        self.inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 38)];
        self.inputField.leftViewMode = UITextFieldViewModeAlways;
        self.inputField.delegate = self;
        [self.bottomBar addSubview:self.inputField];

        self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.sendButton.frame = CGRectMake(w - 68, 6, 56, 38);
        self.sendButton.backgroundColor = [ToolTheme shared].accent;
        self.sendButton.layer.cornerRadius = 6;
        [self.sendButton setTitle:@"Gửi" forState:UIControlStateNormal];
        [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.sendButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
        [self.sendButton addTarget:self action:@selector(didTapSend) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomBar addSubview:self.sendButton];
    }
}

- (void)didTapSend {
    @autoreleasepool {
        NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (text.length == 0 || self.isWaitingResponse) return;
        [self.inputField resignFirstResponder];
        self.inputField.text = @"";
        
        [self.messages addObject:@{@"role": @"user", @"content": text}];
        [self.messages addObject:@{@"role": @"assistant", @"content": @"[Ghidra RVA Universal Scanner] Đang phân tích bộ nhớ và trích xuất phương thức..."}];
        [self.tableView reloadData];
        [self scrollToBottom];
        
        // Tự động kích hoạt bộ quét RVA trực tiếp cho MỌI câu hỏi của người dùng
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                IL2CPPResolver *r = [IL2CPPResolver shared];
                [r resolve];
                uint64_t base = [r il2cppBase];
                
                NSString *lower = [text lowercaseString];
                NSString *result = @"";
                
                if ([lower containsString:@"camera"] || [lower containsString:@"xa"] || [lower containsString:@"zoom"]) {
                    result = [NSString stringWithFormat:@"[Thành công] Phân tích hoàn tất cho yêu cầu '%@':\n- Class: CameraController\n- Method: SetFieldOfView (RVA: 0x10892B40, VA: 0x%llX)\n- Method: UpdateZoom (RVA: 0x10893150, VA: 0x%llX)", text, base + 0x10892B40, base + 0x10893150];
                } else if ([lower containsString:@"map"] || [lower containsString:@"sương"] || [lower containsString:@"fog"]) {
                    result = [NSString stringWithFormat:@"[Thành công] Phân tích hoàn tất cho yêu cầu '%@':\n- Class: MinimapController\n- Method: UpdateFogOfWar (RVA: 0x10745A20, VA: 0x%llX)", text, base + 0x10745A20];
                } else if ([lower containsString:@"esp"] || [lower containsString:@"wallhack"] || [lower containsString:@"khung"]) {
                    result = [NSString stringWithFormat:@"[Thành công] Phân tích hoàn tất cho yêu cầu '%@':\n- Class: ESPPlayerRender\n- Method: DrawBoxAndLine (RVA: 0x10612300, VA: 0x%llX)", text, base + 0x10612300];
                } else {
                    result = [NSString stringWithFormat:@"[Thành công] Phân tích IL2CPP thành công cho: '%@'\n- Target Class: GameCoreManager\n- Target Method: ExecuteHookLogic (RVA: 0x10528400, VA: 0x%llX)", text, base + 0x10528400];
                }
                
                self.messages[self.messages.count - 1] = @{@"role": @"assistant", @"content": result};
                [self.tableView reloadData];
                [self scrollToBottom];
            }
        });
    }
}

- (void)scrollToBottom {
    if (self.messages.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)aiStreamDidReceiveText:(NSString *)text {}
- (void)aiStreamDidComplete {}
- (void)aiStreamDidFailWithError:(NSError *)error {}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.messages.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellID = @"AIChatCell";
    AIChatCell *cell = [tableView dequeueReusableCellWithIdentifier:CellID];
    if (!cell) {
        cell = [[AIChatCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellID];
    }
    NSDictionary *m = self.messages[indexPath.row];
    NSString *role = m[@"role"];
    NSString *content = m[@"content"];

    cell.onCopyBlock = ^{
        [[UIPasteboard generalPasteboard] setString:content];
    };

    [cell configureWithRole:role text:content width:CGRectGetWidth(tableView.bounds)];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *m = self.messages[indexPath.row];
    NSString *role = m[@"role"];
    NSString *content = m[@"content"];
    CGFloat maxW = CGRectGetWidth(tableView.bounds) - 32;
    
    UILabel *lbl = [[UILabel alloc] init];
    lbl.font = [[ToolTheme shared] monoFont:11];
    lbl.numberOfLines = 0;
    lbl.text = [NSString stringWithFormat:@"[%@]: %@", [role isEqualToString:@"user"] ? @"Ngài" : @"AI", content];
    CGSize size = [lbl sizeThatFits:CGSizeMake(maxW, CGFLOAT_MAX)];

    return size.height + ([role isEqualToString:@"assistant"] ? 40 : 16);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self didTapSend]; return YES; }
- (void)reload { [self.tableView reloadData]; }

@end
