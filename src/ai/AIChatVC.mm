#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"
#import "AIMemoryTool.h"
#import "AIESPTool.h"
#import "GameFingerprint.h"
#import "ToolTheme.h"

static const CGFloat kInputBarHeight = 50;

@interface AIChatVC () <AIStreamDelegate, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *inputArea;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *items;
@property (nonatomic, assign) BOOL isWaiting;
@property (nonatomic, strong) NSMutableString *currentAIResponse;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"[AI] viewDidLoad START");

    self.view.backgroundColor = [ToolTheme shared].background;
    self.items = [NSMutableArray array];

    @try {
        [AITool registerAll];
        [AIMemoryTool registerAll];
        [AIESPTool registerAll];
    } @catch (NSException *e) {
        NSLog(@"[AI] Register tools exception: %@", e);
    }

    [self buildUI];
    [self setupKeyboardObservers];

    NSString *welcome = @"AI Agent & Ghidra ready.\nHỏi: phân tích Ghidra, hack map, viết code C++/Lua...";
    [self.items addObject:@{@"type": @"ai", @"text": welcome}];
    [self.tableView reloadData];

    NSLog(@"[AI] viewDidLoad DONE");
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h - kInputBarHeight)
                                                     style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [ToolTheme shared].background;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 50;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.alwaysBounceVertical = YES;
    self.tableView.showsVerticalScrollIndicator = YES;
    self.tableView.scrollEnabled = YES;
    self.tableView.delaysContentTouches = NO;
    self.tableView.canCancelContentTouches = YES;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Fix padding top & bottom để không bị che khuất đoạn chat cuối và đầu
    self.tableView.contentInset = UIEdgeInsetsMake(12, 0, 24, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(12, 0, 24, 0);
    
    [self.view addSubview:self.tableView];

    self.inputArea = [[UIView alloc] initWithFrame:CGRectMake(0, h - kInputBarHeight, w, kInputBarHeight)];
    self.inputArea.backgroundColor = [ToolTheme shared].surface;
    self.inputArea.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.inputArea];

    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 1)];
    topLine.backgroundColor = [ToolTheme shared].divider;
    [self.inputArea addSubview:topLine];

    self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(10, 10, w - 80, 30)];
    self.inputField.backgroundColor = [ToolTheme shared].background;
    self.inputField.textColor = [ToolTheme shared].textPrimary;
    self.inputField.font = [[ToolTheme shared] monoFont:11];
    self.inputField.layer.borderWidth = 1;
    self.inputField.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.inputField.layer.cornerRadius = 4;
    self.inputField.returnKeyType = UIReturnKeySend;
    self.inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 30)];
    self.inputField.leftViewMode = UITextFieldViewModeAlways;
    self.inputField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"Hỏi Ghidra, C++, Lua..."
            attributes:@{NSForegroundColorAttributeName: [ToolTheme shared].textMuted}];
    self.inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputField addTarget:self action:@selector(sendTapped)
              forControlEvents:UIControlEventEditingDidEndOnExit];
    [self.inputArea addSubview:self.inputField];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(w - 64, 10, 54, 30);
    self.sendButton.backgroundColor = [ToolTheme shared].accent;
    self.sendButton.layer.cornerRadius = 4;
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton addTarget:self action:@selector(sendTapped)
              forControlEvents:UIControlEventTouchUpInside];
    [self.inputArea addSubview:self.sendButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
        UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [ToolTheme shared].accent;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    self.spinner.userInteractionEnabled = NO;
    [self.view addSubview:self.spinner];
}

#pragma mark - Keyboard

- (void)setupKeyboardObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    CGRect kbFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval dur = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGRect kbInView = [self.view convertRect:kbFrame fromView:nil];
    CGFloat overlap = CGRectGetHeight(self.view.bounds) - CGRectGetMinY(kbInView);

    [UIView animateWithDuration:dur animations:^{
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);
        CGFloat visibleH = h - overlap;
        self.tableView.frame = CGRectMake(0, 0, w, visibleH - kInputBarHeight);
        self.inputArea.frame = CGRectMake(0, visibleH - kInputBarHeight, w, kInputBarHeight);
    } completion:^(BOOL finished) {
        [self scrollToBottomAnimated:YES];
    }];
}

- (void)keyboardWillHide:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    NSTimeInterval dur = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:dur animations:^{
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);
        self.tableView.frame = CGRectMake(0, 0, w, h - kInputBarHeight);
        self.inputArea.frame = CGRectMake(0, h - kInputBarHeight, w, kInputBarHeight);
    }];
}

#pragma mark - Send

- (void)sendTapped {
    NSString *text = self.inputField.text;
    if (text.length == 0 || self.isWaiting) return;

    [self.items addObject:@{@"type": @"user", @"text": text}];
    self.inputField.text = @"";
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];

    self.isWaiting = YES;
    self.currentAIResponse = [NSMutableString string];
    self.sendButton.enabled = NO;
    self.sendButton.alpha = 0.5;
    [self.spinner startAnimating];

    NSMutableArray *history = [NSMutableArray array];
    NSInteger maxHistory = 6;
    NSInteger start = MAX(0, (NSInteger)self.items.count - maxHistory);
    for (NSInteger i = start; i < (NSInteger)self.items.count; i++) {
        NSDictionary *item = self.items[i];
        NSString *type = item[@"type"];
        if ([type isEqualToString:@"user"]) {
            [history addObject:@{@"role": @"user", @"content": item[@"text"]}];
        } else if ([type isEqualToString:@"ai"]) {
            [history addObject:@{@"role": <<"assistant", @"content": item[@"text"]}];
        }
    }

    NSMutableArray *tools = [NSMutableArray array];
    for (AITool *t in [AITool allTools]) {
        [tools addObject:[t openAISchema]];
    }

    __weak typeof(self) ws = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        NSString *game = @"Unknown";
        @try {
            game = [[GameFingerprint shared] detectedGame];
        } @catch (NSException *e) {
            game = @"Unknown";
        }

        // Cập nhật System Prompt hỗ trợ tích hợp Ghidra, C++ và Lua
        NSString *sysPrompt = [NSString stringWithFormat:
            @"Bạn là AI agent hack game IL2CPP iOS và Reverse Engineer chuyên nghiệp dùng Ghidra.\n"
            @"- Khi cần phân tích mã lệnh tĩnh, dịch ngược hàm hoặc offset, hãy sử dụng tool `analyze_ghidra`.\n"
            @"- Khi người dùng yêu cầu đưa mã qua tab Lua, hãy đặt toàn bộ mã nguồn trong thẻ ```lua ... ```.\n"
            @"- Khi người dùng yêu cầu đưa mã qua tab C++, hãy đặt toàn bộ mã nguồn trong thẻ ```cpp ... ```.\n"
            @"Game hiện tại: %@\n", game];

        NSMutableArray *messages = [NSMutableArray array];
        [messages addObject:@{@"role": @"system", @"content": sysPrompt}];
        [messages addObjectsFromArray:history];

        [[AIProvider shared] sendMessages:messages tools:tools delegate:ws];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (ws.isWaiting) {
            ws.isWaiting = NO;
            ws.sendButton.enabled = YES;
            ws.sendButton.alpha = 1.0;
            [ws.spinner stopAnimating];
            [ws.items addObject:@{@"type": @"error", @"text": @"Timeout 60s"}];
            [ws.tableView reloadData];
            [ws scrollToBottomAnimated:YES];
        }
    });
}

#pragma mark - Scroll

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.items.count == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger last = (NSInteger)self.items.count - 1;
        NSIndexPath *ip = [NSIndexPath indexPathForRow:last inSection:0];
        [self.tableView scrollToRowAtIndexPath:ip
                              atScrollPosition:UITableViewScrollPositionBottom
                                      animated:animated];
    });
}

- (void)scrollToBottom { [self scrollToBottomAnimated:YES]; }

#pragma mark - AIStreamDelegate

- (void)aiStreamDidReceiveText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.currentAIResponse appendString:text ?: @""];
        NSInteger lastIdx = (NSInteger)self.items.count - 1;
        if (lastIdx >= 0 && [self.items[lastIdx][@"type"] isEqualToString:@"ai"]) {
            self.items[lastIdx] = @{@"type": @"ai", @"text": [self.currentAIResponse copy]};
        } else {
            [self.items addObject:@{@"type": @"ai", @"text": [self.currentAIResponse copy]}];
        }
        [self.tableView reloadData];
        [self scrollToBottomAnimated:YES];
    });
}

- (void)aiStreamDidFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        self.isWaiting = NO;
        self.sendButton.enabled = YES;
        self.sendButton.alpha = 1.0;
        [self.items addObject:@{@"type": @"error",
            @"text": error.localizedDescription ?: @"Lỗi kết nối"}];
        [self.tableView reloadData];
        [self scrollToBottomAnimated:YES];
    });
}

- (void)aiStreamDidComplete {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        self.isWaiting = NO;
        self.sendButton.enabled = YES;
        self.sendButton.alpha = 1.0;
    });
}

- (void)aiDidCallTool:(NSString *)toolName args:(NSDictionary *)args result:(id)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *summary = @"OK";
        if ([result isKindOfClass:[NSDictionary class]]) {
            NSDictionary *d = (NSDictionary *)result;
            if (d[@"error"]) summary = [NSString stringWithFormat:@"error: %@", d[@"error"]];
            else if (d[@"count"]) summary = [NSString stringWithFormat:@"%@ kết quả", d[@"count"]];
        }
        [self.items addObject:@{@"type": @"tool",
            @"text": [NSString stringWithFormat:@"%@ → %@", toolName, summary]}];
        [self.tableView reloadData];
        [self scrollToBottomAnimated:YES];
    });
}

#pragma mark - Table & Syntax Highlighting Helpers

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *CellID = @"AIChatCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:CellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellID];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];

    NSDictionary *item = self.items[ip.row];
    NSString *type = item[@"type"];
    NSString *text = item[@"text"] ?: @"";
    BOOL isUser = [type isEqualToString:@"user"];
    BOOL isTool = [type isEqualToString:@"tool"];
    BOOL isError = [type isEqualToString:@"error"];

    NSString *prefix = @"> ";
    UIColor *prefixColor = [ToolTheme shared].accent;
    if (isTool) { prefix = @"[tool] "; prefixColor = [ToolTheme shared].warning; }
    else if (isError) { prefix = @"[error] "; prefixColor = [ToolTheme shared].danger; }
    else if (!isUser) { prefix = @"[ai] "; prefixColor = [ToolTheme shared].success; }

    NSString *full = [NSString stringWithFormat:@"%@%@", prefix, text];
    CGFloat cellW = CGRectGetWidth(tv.bounds);

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, cellW - 24, 0)];
    label.numberOfLines = 0;

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full];
    [attr addAttribute:NSForegroundColorAttributeName value:prefixColor range:NSMakeRange(0, prefix.length)];
    
    UIColor *textColor = isError ? [ToolTheme shared].danger : [ToolTheme shared].textPrimary;
    [attr addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(prefix.length, text.length)];
    [attr addAttribute:NSFontAttributeName value:[[ToolTheme shared] monoFont:11] range:NSMakeRange(0, full.length)];

    if (!isUser && !isError) {
        NSArray *keywords = @[@"void", @"bool", @"int", @"uint64_t", @"float", @"double", @"char", @"const", @"return", @"if", @"else", @"for", @"while", @"struct", @"class", @"#import", @"#include", @"auto", @"static", @"true", @"false", @"nullptr", @"local", @"function", @"end", @"print", @"then", @"do"];
        NSString *lowerStr = full.lowercaseString;
        for (NSString *kw in keywords) {
            NSRange range = [lowerStr rangeOfString:kw];
            while (range.location != NSNotFound) {
                [attr addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.40 green:0.80 blue:1.00 alpha:1.0] range:range];
                
                if (range.location + range.length >= lowerStr.length) break;
                range = [lowerStr rangeOfString:kw options:0 range:NSMakeRange(range.location + range.length, lowerStr.length - (range.location + range.length))];
            }
        }
    }

    label.attributedText = attr;

    CGSize maxSize = CGSizeMake(cellW - 24, CGFLOAT_MAX);
    CGRect rect = [attr boundingRectWithSize:maxSize
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                     context:nil];
    label.frame = CGRectMake(12, 8, cellW - 24, ceil(rect.size.height));
    [cell.contentView addSubview:label];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    NSString *text = item[@"text"] ?: @"";
    NSString *full = [NSString stringWithFormat:@"> %@", text];
    CGFloat cellW = CGRectGetWidth(tableView.bounds);
    
    UIFont *font = [[ToolTheme shared] monoFont:11];
    NSDictionary *attrs = @{NSFontAttributeName: font};
    CGRect rect = [full boundingRectWithSize:CGSizeMake(cellW - 24, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:attrs
                                     context:nil];
    return ceil(rect.size.height) + 16;
}

- (void)reload { [self.tableView reloadData]; }

@end
