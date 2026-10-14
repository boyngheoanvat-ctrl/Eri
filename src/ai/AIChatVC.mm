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

#pragma mark - TEST E: bật cả 3 registerAll, KHÔNG gọi GameFingerprint

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"[TEST-E] viewDidLoad START");

    self.view.backgroundColor = [ToolTheme shared].background;
    self.items = [NSMutableArray array];
    NSLog(@"[TEST-E] after init vars");

    NSLog(@"[TEST-E] AITool registerAll START");
    [AITool registerAll];
    NSLog(@"[TEST-E] AITool registerAll DONE");

    NSLog(@"[TEST-E] AIMemoryTool registerAll START");
    [AIMemoryTool registerAll];
    NSLog(@"[TEST-E] AIMemoryTool registerAll DONE");

    NSLog(@"[TEST-E] AIESPTool registerAll START");
    [AIESPTool registerAll];
    NSLog(@"[TEST-E] AIESPTool registerAll DONE");

    NSLog(@"[TEST-E] all registerAll DONE");

    NSLog(@"[TEST-E] before buildUI");
    [self buildUI];
    NSLog(@"[TEST-E] after buildUI");

    NSLog(@"[TEST-E] before setupKeyboardObservers");
    [self setupKeyboardObservers];
    NSLog(@"[TEST-E] after setupKeyboardObservers");

    // KHÔNG gọi GameFingerprint
    NSString *game = @"Unknown";

    NSString *welcome = [NSString stringWithFormat:
        @"AI Agent ready.\nGame: %@\nHoi: hack map, hack speed, tim class...", game];
    [self.items addObject:@{@"type": @"ai", @"text": welcome}];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:NO];

    NSLog(@"[TEST-E] viewDidLoad DONE");
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

#pragma mark - Send (TEST: không gọi AI)

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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.items addObject:@{@"type": @"ai", @"text": @"[TEST-E] Da nhan tin nhan (khong goi AI)"}];
        [self.tableView reloadData];
        [self scrollToBottomAnimated:YES];

        self.isWaiting = NO;
        self.sendButton.enabled = YES;
        self.sendButton.alpha = 1.0;
        [self.spinner stopAnimating];
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
        [self.items addObject:@{@"type": @"tool",
            @"text": [NSString stringWithFormat:@"%@ → OK", toolName]}];
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
