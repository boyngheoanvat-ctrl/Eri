#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"
#import "AIMemoryTool.h"
#import "AIESPTool.h"
#import "ToolTheme.h"

@interface AIChatVC () <AIStreamDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
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
    self.view.backgroundColor = [ToolTheme shared].background;
    self.items = [NSMutableArray array];

    [AITool registerAll];
    [AIMemoryTool registerAll];
    [AIESPTool registerAll];

    [self buildUI];

    [self.items addObject:@{
        @"type": @"ai",
        @"text": @"AI Agent ready.\nHoi: tim class quan ly entity, hack map, tim gia tri 100"
    }];
    [self.tableView reloadData];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    CGFloat inputH = 50;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h - inputH)
                                                     style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [ToolTheme shared].background;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 40;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    UIView *inputArea = [[UIView alloc] initWithFrame:CGRectMake(0, h - inputH, w, inputH)];
    inputArea.backgroundColor = [ToolTheme shared].surface;
    inputArea.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:inputArea];

    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 1)];
    topLine.backgroundColor = [ToolTheme shared].divider;
    [inputArea addSubview:topLine];

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
    [inputArea addSubview:self.inputField];

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
    [inputArea addSubview:self.sendButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
        UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [ToolTheme shared].accent;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

#pragma mark - Send

- (void)sendTapped {
    NSString *text = self.inputField.text;
    if (text.length == 0 || self.isWaiting) return;

    [self.items addObject:@{@"type": @"user", @"text": text}];
    self.inputField.text = @"";
    [self.tableView reloadData];
    [self scrollToBottom];

    self.isWaiting = YES;
    self.currentAIResponse = [NSMutableString string];
    self.sendButton.enabled = NO;
    self.sendButton.alpha = 0.5;
    [self.spinner startAnimating];

    NSString *sysPrompt =
        @"AI agent hack game IL2CPP. Tra loi tieng Viet ngan gon.\n"
        @"Tool:\n"
        @"=== ESP / CLASS FINDER ===\n"
        @"- find_entity_manager(): tim class quan ly entity\n"
        @"- find_camera_class(): tim class Camera\n"
        @"- find_static_entity_lists(): tim static list entity\n"
        @"- find_entity_list_methods(): tim method tra list\n"
        @"- full_esp_scan(): quet toan bo\n"
        @"=== CLASS ===\n"
        @"- dump_class_runtime(class_name): dump class\n"
        @"- find_in_class(class_name, keyword): tim field/method\n"
        @"- search_classes(keyword): tim class\n"
        @"- search_methods(class_name, method_keyword): tim method\n"
        @"- get_method_rva(class_name, method_name): lay RVA\n"
        @"- find_hack_methods(hack_type): tim ham hack\n"
        @"=== MEMORY ===\n"
        @"- search_memory(value, type): tim gia tri\n"
        @"- edit_memory(address, value, type): sua gia tri\n"
        @"- read_memory(address, type): doc gia tri\n"
        @"=== FILE ===\n"
        @"- read_file(filename, keyword): grep file\n"
        @"- list_files(): liet ke file\n"
        @"QUY TAC:\n"
        @"- Hoi 'tim class quan ly entity' → find_entity_manager\n"
        @"- Hoi 'tim camera' → find_camera_class\n"
        @"- Hoi 'class X co gi' → dump_class_runtime\n"
        @"- Hoi 'hack map' → find_hack_methods('map')\n"
        @"- Hoi 'tim gia tri X' → search_memory\n"
        @"- Neu tool loi, KHONG goi lai. Tra loi user.";

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
}

- (void)scrollToBottom {
    if (self.items.count == 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:self.items.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last
                          atScrollPosition:UITableViewScrollPositionBottom
                                  animated:YES];
}

#pragma mark - AIStreamDelegate

- (void)aiStreamDidReceiveText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.currentAIResponse appendString:text];

        NSInteger lastIdx = (NSInteger)self.items.count - 1;
        if (lastIdx >= 0 && [self.items[lastIdx][@"type"] isEqualToString:@"ai"]) {
            self.items[lastIdx] = @{@"type": @"ai", @"text": [self.currentAIResponse copy]};
        } else {
            [self.items addObject:@{@"type": @"ai", @"text": [self.currentAIResponse copy]}];
        }

        [self.tableView reloadData];
        [self scrollToBottom];
    });
}

- (void)aiStreamDidFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        self.isWaiting = NO;
        self.sendButton.enabled = YES;
        self.sendButton.alpha = 1.0;

        [self.items addObject:@{
            @"type": @"error",
            @"text": error.localizedDescription ?: @"Loi khong xac dinh"
        }];
        [self.tableView reloadData];
        [self scrollToBottom];
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
        NSString *argsStr = @"";
        if (args.count > 0) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
            argsStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }

        NSString *summary = @"OK";
        if ([result isKindOfClass:[NSDictionary class]]) {
            NSDictionary *d = (NSDictionary *)result;
            if (d[@"error"]) summary = [NSString stringWithFormat:@"error: %@", d[@"error"]];
            else if (d[@"count"]) summary = [NSString stringWithFormat:@"%@ ket qua", d[@"count"]];
            else if (d[@"success"]) summary = [d[@"success"] boolValue] ? @"OK" : @"Fail";
            else if (d[@"edited"]) summary = [NSString stringWithFormat:@"sua %@", d[@"edited"]];
            else if (d[@"field_count"]) summary = [NSString stringWithFormat:@"%@ fields, %@ methods",
                                                    d[@"field_count"], d[@"method_count"]];
            else if (d[@"entity_managers"]) summary = @"scan hoan tat";
        }

        [self.items addObject:@{
            @"type": @"tool",
            @"text": [NSString stringWithFormat:@"%@(%@) → %@", toolName, argsStr, summary]
        }];
        [self.tableView reloadData];
        [self scrollToBottom];
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

    NSString *full = [NSString stringWithFormat:@"%@%@", prefix, text];
    CGFloat cellW = CGRectGetWidth(tv.bounds);

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, cellW - 20, 0)];
    label.numberOfLines = 0;

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full];
    [attr addAttribute:NSForegroundColorAttributeName value:prefixColor range:NSMakeRange(0, prefix.length)];
    UIColor *tc = isError ? [ToolTheme shared].danger : [ToolTheme shared].textPrimary;
    [attr addAttribute:NSForegroundColorAttributeName value:tc range:NSMakeRange(prefix.length, text.length)];
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

- (void)reload {
    [self.tableView reloadData];
}

@end
