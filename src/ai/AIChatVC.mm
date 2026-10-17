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
            @{@"role": @"assistant", @"content": @"Hello Người Anh Em !!!\n"
                                                 @"💳 Cre : Eri Nguyễn 💳\n"
                                                 @"📞 Zalo : 0896734790 📞\n"
                                                 @"🎵 Facebook : Nguyễn Minh Thiện 🎵"}
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
        self.inputField.placeholder = @"Nhập đoạn chat ở đây...";
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
        NSString *userInput = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (userInput.length == 0 || self.isWaitingResponse) return;
        [self.inputField resignFirstResponder];
        self.inputField.text = @"";
        
        [self.messages addObject:@{@"role": @"user", @"content": userInput}];
        
        NSString *lower = [userInput lowercaseString];
        
        BOOL isGreeting = [lower containsString:@"hi"] || [lower containsString:@"hello"] || [lower containsString:@"chào"] || [lower containsString:@"hướng dẫn"] || [lower containsString:@"giúp"];
        if (isGreeting && userInput.length < 15) {
            NSString *reply = @"Chào người anh em tôi là tool do Eri Nguyễn tạo ra";
            [self.messages addObject:@{@"role": @"assistant", @"content": reply}];
            [self.tableView reloadData];
            [self scrollToBottom];
            return;
        }
        
        [self.messages addObject:@{@"role": @"assistant", @"content": [NSString stringWithFormat:@"[Adaptive Scan] Đang phân tích động file dump.cs cho yêu cầu '%@'...", userInput]}];
        [self.tableView reloadData];
        [self scrollToBottom];
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                // Phân tích linh hoạt ý định người dùng thành tập hợp từ khóa ngữ nghĩa rộng
                NSMutableArray *semanticKeywords = [NSMutableArray array];
                
                if ([lower containsString:@"map"] || [lower containsString:@"bản đồ"] || [lower containsString:@"sương"] || [lower containsString:@"mini"] || [lower containsString:@"địch"] || [lower containsString:@"sight"] || [lower containsString:@"nhìn"]) {
                    [semanticKeywords addObjectsFromArray:@[@"sight", @"reveal", @"fog", @"map", @"radar", @"visib", @"entity", @"actor", @"target"]];
                } else if ([lower containsString:@"camera"] || [lower containsString:@"xa"] || [lower containsString:@"zoom"]) {
                    [semanticKeywords addObjectsFromArray:@[@"fov", @"fieldofview", @"zoom", @"camera", @"ortho"]];
                } else if ([lower containsString:@"cao"] || [lower containsString:@"bay"] || [lower containsString:@"fly"] || [lower containsString:@"jump"]) {
                    [semanticKeywords addObjectsFromArray:@[@"position", @"jump", @"gravity", @"velocity", @"move", @"transform"]];
                } else if ([lower containsString:@"tốc độ"] || [lower containsString:@"speed"] || [lower containsString:@"nhanh"]) {
                    [semanticKeywords addObjectsFromArray:@[@"speed", @"velocity", @"run", @"move"]];
                } else if ([lower containsString:@"máu"] || [lower containsString:@"hp"] || [lower containsString:@"bất tử"] || [lower containsString:@"damage"]) {
                    [semanticKeywords addObjectsFromArray:@[@"health", @"takedamage", @"hp", @"damage", @"god"]];
                } else {
                    // Tự tách từ khóa người dùng nhập để quét đa năng mọi game
                    NSArray *tokens = [userInput componentsSeparatedByString:@" "];
                    for (NSString *t in tokens) {
                        if (t.length > 1) [semanticKeywords addObject:[t lowercaseString]];
                    }
                }
                
                NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
                NSString *csPath = [docs stringByAppendingPathComponent:@"IL2CPP_Dump/dump.cs"];
                
                NSString *finalResult = @"";
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:csPath]) {
                    NSError *error = nil;
                    NSString *content = [NSString stringWithContentsOfFile:csPath encoding:NSUTF8StringEncoding error:&error];
                    if (content && content.length > 0) {
                        NSArray *lines = [content componentsSeparatedByString:@"\n"];
                        
                        NSMutableArray *matchedCandidates = [NSMutableArray array];
                        NSString *currentNamespace = @"GlobalNamespace";
                        NSString *currentClass = @"UnknownClass";
                        
                        for (NSString *line in lines) {
                            if ([line hasPrefix:@"namespace "]) {
                                currentNamespace = [[line stringByReplacingOccurrencesOfString:@"namespace " withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            }
                            if ([line containsString:@"class "] || [line containsString:@"struct "]) {
                                currentClass = line;
                            }
                            
                            NSString *lowerNs = [currentNamespace lowercaseString];
                            NSString *lowerCls = [currentClass->description lowercaseString];
                            
                            // Loại bỏ triệt để thư viện hệ thống .NET/Mono/Unity chuẩn để tool có thể dùng trên bất kỳ game Unity nào
                            if ([lowerNs hasPrefix:@"system"] || 
                                [lowerNs hasPrefix:@"mono"] || 
                                [lowerNs hasPrefix:@"unityengine"] || 
                                [lowerNs hasPrefix:@"unityeditor"] ||
                                [lowerNs hasPrefix:@"interopservices"] ||
                                [lowerNs hasPrefix:@"nunit"] ||
                                [lowerCls containsString:@"<>c"] ||
                                [lowerCls containsString:@"<module>"]) {
                                continue;
                            }
                            
                            // Nếu tìm thấy dòng phương thức có RVA
                            if ([line containsString:@"RVA: 0x"] && [line containsString:@"("]) {
                                NSString *lowerLine = [line lowercaseString];
                                NSInteger score = 0;
                                
                                for (NSString *kw in semanticKeywords) {
                                    if ([lowerLine containsString:kw] || [lowerCls containsString:kw]) {
                                        score += 2; // Khớp tên hàm hoặc class
                                    }
                                }
                                
                                if (score > 0) {
                                    NSDictionary *matchInfo = @{
                                        @"score": @(score),
                                        @"namespace": currentNamespace,
                                        @"class": currentClass,
                                        @"method": line
                                    };
                                    [matchedCandidates addObject:matchInfo];
                                }
                            }
                        }
                        
                        // Sắp xếp các kết quả theo điểm số phù hợp nhất (Score cao nhất lên đầu)
                        [matchedCandidates sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                            NSNumber *s1 = obj1[@"score"];
                            NSNumber *s2 = obj2[@"score"];
                            return [s2 compare:s1];
                        }];
                        
                        if (matchedCandidates.count > 0) {
                            IL2CPPResolver *r = [IL2CPPResolver shared];
                            [r resolve];
                            uint64_t base = [r il2cppBase];
                            
                            // Lấy kết quả có điểm số cao nhất chuẩn xác nhất
                            NSDictionary *best = matchedCandidates.firstObject;
                            
                            NSMutableString *resStr = [NSMutableString stringWithFormat:@"[Adaptive Scan - Tìm thấy hàm tối ưu cho '%@']\n", userInput];
                            [resStr appendFormat:@"- Namespace: %@\n", best[@"namespace"]];
                            [resStr appendFormat:@"- Class: %@\n", best[@"class"]];
                            [resStr appendFormat:@"- Method: %@\n", best[@"method"]];
                            [resStr appendFormat:@"- Base Address: 0x%llX\n", base];
                            
                            // Nếu có thêm kết quả phụ tiềm năng, liệt kê ngắn gọn để ngài tham khảo
                            if (matchedCandidates.count > 1) {
                                [resStr appendString:@"\n(Các hàm dự phòng tiềm năng khác đã được lọc tự động)."];
                            }
                            
                            finalResult = resStr;
                        } else {
                            finalResult = [NSString stringWithFormat:@"[Thông báo] Không tìm thấy hàm logic phù hợp cho '%@' trong game này. Ngài hãy đảm bảo đã generate file dump.cs của tựa game hiện tại nhé!", userInput];
                        }
                    } else {
                        finalResult = @"[Lỗi] File dump.cs trống. Ngài vui lòng sang tab 'Dump' bấm Generate Dump trước!";
                    }
                } else {
                    finalResult = @"[Lỗi] Chưa có file dump.cs. Ngài hãy sang tab 'Dump' thực hiện Generate Dump trước!";
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        self.messages[self.messages.count - 1] = @{@"role": @"assistant", @"content": finalResult};
                        [self.tableView reloadData];
                        [self scrollToBottom];
                    }
                });
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
    lbl.text = [NSString stringWithFormat:@"[%@]: %@", [role isEqualToString:"user"] ? @"Ngài" : @"AI", content];
    CGSize size = [lbl sizeThatFits:CGSizeMake(maxW, CGFLOAT_MAX)];

    return size.height + ([role isEqualToString:@"assistant"] ? 40 : 16);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self didTapSend]; return YES; }
- (void)reload { [self.tableView reloadData]; }

@end
