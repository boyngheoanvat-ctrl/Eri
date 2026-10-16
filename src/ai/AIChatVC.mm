#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"

@interface AIChatVC () <UITextFieldDelegate, AIStreamDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messages;
@property (nonatomic, assign) BOOL isWaitingResponse;
@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    if (!self.messages) {
        self.messages = [NSMutableArray arrayWithArray:@[
            @{@"role": @"assistant", @"content": @"[AI & Ghidra Suite Ready] Chào ngài, hệ thống phân tích tĩnh RVA đã sẵn sàng."}
        ]];
    }
    [self buildUI];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);
        if (w <= 50) w = 450;
        if (h <= 50) h = 300;

        CGFloat bottomH = 54;
        CGFloat tableH = h - bottomH - 16;

        self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, tableH) style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.dataSource = self;
        self.tableView.delegate = self;
        [self.view addSubview:self.tableView];

        UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - bottomH, w, bottomH)];
        bottomBar.backgroundColor = [ToolTheme shared].surface;
        [self.view addSubview:bottomBar];

        self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w - 110, 38)];
        self.inputField.placeholder = @"Nhập câu hỏi AI...";
        self.inputField.backgroundColor = [ToolTheme shared].surfaceAlt;
        self.inputField.textColor = [ToolTheme shared].textPrimary;
        self.inputField.font = [[ToolTheme shared] monoFont:12];
        self.inputField.layer.cornerRadius = 6;
        self.inputField.delegate = self;
        [bottomBar addSubview:self.inputField];

        self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.sendButton.frame = CGRectMake(w - 94, 8, 82, 38);
        self.sendButton.backgroundColor = [ToolTheme shared].accent;
        [self.sendButton setTitle:@"Gửi" forState:UIControlStateNormal];
        [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.sendButton addTarget:self action:@selector(didTapSend) forControlEvents:UIControlEventTouchUpInside];
        [bottomBar addSubview:self.sendButton];
    }
}

- (void)didTapSend {
    @autoreleasepool {
        NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (text.length == 0 || self.isWaitingResponse) return;
        [self.inputField resignFirstResponder];
        self.inputField.text = @"";
        [self.messages addObject:@{@"role": @"user", @"content": text}];
        [self.messages addObject:@{@"role": @"assistant", @"content": @"[Đang phân tích Ghidra RVA...]"}];
        [self.tableView reloadData];
        self.isWaitingResponse = YES;
        NSMutableArray *apiMessages = [NSMutableArray array];
        for (NSDictionary *m in self.messages) {
            if ([m[@"content"] isEqualToString:@"[Đang phân tích Ghidra RVA...]"]) continue;
            [apiMessages addObject:@{@"role": m[@"role"], @"content": m[@"content"]}];
        }
        [[AIProvider shared] sendMessages:apiMessages tools:@[] delegate:self];
    }
}

- (void)aiStreamDidReceiveText:(NSString *)text {
    @autoreleasepool {
        if (self.messages.count > 0) {
            self.messages[self.messages.count - 1] = @{@"role": @"assistant", @"content": text ?: @"[Không có phản hồi]"};
        }
        [self.tableView reloadData];
    }
}

- (void)aiStreamDidComplete { self.isWaitingResponse = NO; }
- (void)aiStreamDidFailWithError:(NSError *)error { self.isWaitingResponse = NO; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.messages.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ChatCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [[ToolTheme shared] monoFont:11];
    }
    NSDictionary *m = self.messages[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"[%@]: %@", [m[@"role"] isEqualToString:@"user"] ? @"Ngài" : @"AI", m[@"content"]];
    cell.textLabel.textColor = [m[@"role"] isEqualToString:@"user"] ? [ToolTheme shared].accent : [ToolTheme shared].textPrimary;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return UITableViewAutomaticDimension; }
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self didTapSend]; return YES; }
- (void)reload { [self.tableView reloadData]; }

@end
