#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"

@interface AIChatVC () <AIStreamDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *chatScrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextView *chatLogTextView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UIButton *sendButton;

@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    
    CGRect bounds = self.view.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
    // 1. Khung chứa input và nút gửi ở đáy (chiều cao 50px, tự động co giãn theo chiều ngang khi kéo cửa sổ)
    CGFloat bottomBarHeight = 50;
    CGFloat inputHeight = 36;
    
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, height - bottomBarHeight, width, bottomBarHeight)];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.bottomBar.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.20 alpha:1.0];
    [self.view addSubview:self.bottomBar];
    
    // 2. Nút Send nằm sát góc phải
    CGFloat sendBtnWidth = 60;
    CGFloat padding = 10;
    
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(width - sendBtnWidth - padding, (bottomBarHeight - inputHeight) / 2, sendBtnWidth, inputHeight);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    self.sendButton.layer.cornerRadius = 6;
    self.sendButton.layer.masksToBounds = YES;
    [self.sendButton addTarget:self action:@selector(didTapSend) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.sendButton];
    
    // 3. Ô nhập liệu (inputTextView) co giãn linh hoạt theo chiều rộng cửa sổ
    CGFloat inputWidth = width - sendBtnWidth - (padding * 3);
    self.inputTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, (bottomBarHeight - inputHeight) / 2, inputWidth, inputHeight)];
    self.inputTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.inputTextView.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.28 alpha:1.0];
    self.inputTextView.textColor = [UIColor whiteColor];
    self.inputTextView.font = [UIFont systemFontOfSize:14];
    self.inputTextView.layer.cornerRadius = 6;
    self.inputTextView.layer.masksToBounds = YES;
    self.inputTextView.delegate = self;
    [self.bottomBar addSubview:self.inputTextView];
    
    // 4. UIScrollView hiển thị nội dung chat phía trên
    CGFloat scrollHeight = height - bottomBarHeight;
    self.chatScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, scrollHeight)];
    self.chatScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.chatScrollView];
    
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, scrollHeight)];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.chatScrollView addSubview:self.contentView];
    
    // 5. TextView chứa lịch sử chat
    self.chatLogTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, width - 20, scrollHeight - 20)];
    self.chatLogTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.chatLogTextView.editable = NO;
    self.chatLogTextView.scrollEnabled = NO;
    self.chatLogTextView.backgroundColor = [UIColor clearColor];
    self.chatLogTextView.textColor = [UIColor whiteColor];
    self.chatLogTextView.font = [UIFont systemFontOfSize:13];
    self.chatLogTextView.text = @"[ai] AI Agent ready.\nHoi: hack map, hack speed, tim class...\n";
    [self.contentView addSubview:self.chatLogTextView];
    
    [self updateLayoutContent];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Đồng bộ lại kích thước nội dung khi giao diện bị kéo thay đổi kích thước (resize/drag)
    [self updateLayoutContent];
}

- (void)reload {
    [self.view setNeedsLayout];
    [self.contentView setNeedsLayout];
}

#pragma mark - Actions & Logic

- (void)didTapSend {
    NSString *text = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    self.inputTextView.text = @"";
    
    // Hiển thị câu hỏi của user lên khung chat
    NSString *current = self.chatLogTextView.text ?: @"";
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n> %@", current, text];
    [self updateLayoutContent];
    
    // Đảm bảo tất cả các tool đã được đăng ký và an toàn tuyệt đối chống crash nil object
    [AITool registerAll];
    
    NSMutableArray *tools = [NSMutableArray array];
    NSArray *toolNames = @[@"find_concept", @"search_classes", @"dump_class_runtime", @"find_method_global"];
    for (NSString *name in toolNames) {
        AITool *t = [AITool toolNamed:name];
        if (t) {
            NSDictionary *schema = [t openAISchema];
            if (schema) {
                [tools addObject:schema];
            }
        }
    }
    
    NSArray *messages = @[@{@"role": @"user", @"content": text}];
    [[AIProvider shared] sendMessages:messages tools:tools delegate:self];
}

- (void)updateLayoutContent {
    CGFloat currentWidth = self.chatScrollView.bounds.size.width;
    if (currentWidth <= 0) currentWidth = self.view.bounds.size.width;
    
    CGSize size = [self.chatLogTextView sizeThatFits:CGSizeMake(currentWidth - 20, CGFLOAT_MAX)];
    CGFloat newHeight = MAX(size.height + 20, self.chatScrollView.bounds.size.height);
    
    CGRect frame = self.chatLogTextView.frame;
    frame.size.width = currentWidth - 20;
    frame.size.height = MAX(size.height, self.chatScrollView.bounds.size.height - 20);
    self.chatLogTextView.frame = frame;
    
    self.contentView.frame = CGRectMake(0, 0, currentWidth, newHeight);
    self.chatScrollView.contentSize = CGSizeMake(currentWidth, newHeight);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:YES];
    });
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    UIScrollView *scrollView = self.chatScrollView;
    if (!scrollView) return;
    
    CGFloat bottomOffset = scrollView.contentSize.height - scrollView.bounds.size.height;
    if (bottomOffset > 0) {
        [scrollView setContentOffset:CGPointMake(0, bottomOffset) animated:animated];
    }
}

#pragma mark - AIStreamDelegate

- (void)aiStreamDidReceiveText:(NSString *)text {
    NSString *current = self.chatLogTextView.text ?: @"";
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", current, text];
    [self updateLayoutContent];
}

- (void)aiStreamDidComplete {
    [self updateLayoutContent];
}

- (void)aiStreamDidFailWithError:(NSError *)error {
    NSString *errStr = [NSString stringWithFormat:@"\n[Lỗi] %@", error.localizedDescription];
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogTextView.text ?: @"", errStr];
    [self updateLayoutContent];
}

- (void)aiDidCallTool:(NSString *)toolName args:(NSDictionary *)args result:(id)result {
    NSString *toolLog = [NSString stringWithFormat:@"\n[tool] %@ -> hoàn tất", toolName];
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogTextView.text ?: @"", toolLog];
    [self updateLayoutContent];
}

@end
