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

    [AITool registerAll];
    [AIMemoryTool registerAll];
    [AIESPTool registerAll];

    [self buildUI];
    [self setupKeyboardObservers];

    NSString *welcome = @"AI Agent ready.\nHoi: hack map, hack speed, tim class...";
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
    self.tableView.estimatedRowHeight = 40;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.alwaysBounceVertical = YES;
    self.tableView.showsVerticalScrollIndicator = YES;
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.scrollEnabled = YES;
    self.tableView.delaysContentTouches = NO;
    self.tableView.canCancelContentTouches = YES;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.contentInset = UIEdgeInsetsMake(8, 0, 8, 0);
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
        initWithString:@"input here..."
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

    NSString *game = @"Unknown";
    @try {
        game = [[GameFingerprint shared] detectedGame];
    } @catch (NSException *e) {
        NSLog(@"[AI] GameFingerprint crash: %@", e);
        game = @"Unknown";
    }

    NSString *sysPrompt = [NSString stringWithFormat:
        @"Ban la AI agent hack game IL2CPP iOS. Tra loi tieng Viet ngan gon, chinh xac.\n"
        @"Game hien tai: %@\n"
        @"\n"
        @"=== TOOL ===\n"
        @"1. find_concept(concept) — DUNG DAU TIEN\n"
        @"   concept: map, speed, damage, health, mana, money, cooldown, ammo, level\n"
        @"2. find_method_global(keyword) — tim method toan bo\n"
        @"3. dump_class_runtime(class_name) — xem chi tiet class\n"
        @"4. search_classes(keyword) — tim class\n"
        @"5. find_classes_by_method(method_name)\n"
        @"6. find_method_in_class(class_name, keyword)\n"
        @"7. find_field_in_class(class_name, keyword)\n"
        @"8. read_file(filename, keyword)\n"
        @"\n"
        @"=== QUY TAC ===\n"
        @"1. Cau hoi 'hack X' → find_concept('X')\n"
        @"2. Neu 0 ket qua → find_method_global voi tu khoa tuong tu\n"
        @"3. Cau hoi ve class cu the → dump_class_runtime\n"
        @"4. Tra loi RO: game + class + method + RVA\n"
        @"5. Khong bia RVA. Khong lap tool qua 3 lan.", game];

    NSMutableArray *messages = [NSMutableArray array];
    [messages addObject:@{@"role": @"system", @"content": sysPrompt}];

    NSInteger maxHistory = 6;
    NSInteger start = MAX(0, (NSInteger)self.items.count - maxHistory);
    for (NSInteger i = start; i < (NSInteger)self.items.count; i++) {
        NSDictionary *item = self.items[i];
        NSString *type = item[@"type"];
        if ([type isEqualToString:@"user"]) {
            [messages addObject:@{@"role": @"user", @"content": item[@"text"]}];
        } else if ([type isEqualToString:@"ai"]) {
            [messages addObject:@{@"role": @"assistant", @"content": item[@"text"]}];
        }
    }

    NSMutableArray *tools = [NSMutableArray array];
    for (AITool *t in [AITool allTools]) {
        [tools addObject:[t openAISchema]];
    }

    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
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
            @"text": error.localizedDescription ?: @"Loi"}];
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
            else if (d[@"count"]) summary = [NSString stringWithFormat:@"%@ ket qua", d[@"count"]];
        }
        [self.items addObject:@{@"type": @"tool",
            @"text": [NSString stringWithFormat:@"%@ → %@", toolName, summary]}];
        [self.tableView reloadData];
        [self scrollToBottomAnimated:YES];
    });
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"cell"];
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];

    NSDictionary *item = self.items[ip.row];
    NSString *type = item[@"type"];
    NSString *text = item[@"text"];
    BOOL isUser = [type isEqualToString:@"user"];
    BOOL isTool = [type isEqualToString:@"tool"];
    BOOL isError = [type isEqualToString:@"error"];

    NSString *prefix;
    UIColor *prefixColor;
    if (isUser) { prefix = @"> "; prefixColor = [ToolTheme shared].accent; }
    else if (isTool) { prefix = @"[tool] "; prefixColor = [ToolTheme shared].warning; }
    else if (isError) { prefix = @"[error] "; prefixColor = [ToolTheme shared].danger; }
    else { prefix = @"[ai] "; prefixColor = [ToolTheme shared].success; }

    NSString *full = [NSString stringWithFormat:@"%@%@", prefix, text ?: @""];
    CGFloat cellW = CGRectGetWidth(tv.bounds);

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, cellW - 20, 0)];
    label.numberOfLines = 0;

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full];
    [attr addAttribute:NSForegroundColorAttributeName value:prefixColor range:NSMakeRange(0, prefix.length)];
    UIColor *tc = isError ? [ToolTheme shared].danger : [ToolTheme shared].textPrimary;
    [attr addAttribute:NSForegroundColorAttributeName value:tc range:NSMakeRange(prefix.length, (text ?: @"").length)];
    [attr addAttribute:NSFontAttributeName value:[[ToolTheme shared] monoFont:11] range:NSMakeRange(0, full.length)];

    label.attributedText = attr;

    CGSize maxSize = CGSizeMake(cellW - 20, CGFLOAT_MAX);
    CGRect rect = [attr boundingRectWithSize:maxSize
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                     context:nil];
    label.frame = CGRectMake(10, 6, cellW - 20, rect.size.height);
    [cell.contentView addSubview:label];

    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)reload { [self.tableView reloadData]; }

@end
