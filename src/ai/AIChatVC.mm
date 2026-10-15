#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"

@interface AIChatVC () <AIStreamDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *chatScrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) UILabel *chatLogLabel; // Hoặc UIStackView / UITableView chứa nội dung chat

@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.12 green:0.12. magnitude:0.14 alpha:1.0]; // Điều chỉnh theo màu theme của bạn
    
    self.messages = [NSMutableArray array];
    
    // 1. Khởi tạo UIScrollView chứa nội dung chat
    self.chatScrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.chatScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.chatScrollView];
    
    // 2. ContentView bên trong ScrollView
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    [self.chatScrollView addSubview:self.contentView];
    
    // 3. Label hoặc UIStackView hiển thị lịch sử chat
    self.chatLogLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 12, self.view.bounds.size.width - 24, 100)];
    self.chatLogLabel.numberOfLines = 0;
    self.chatLogLabel.textColor = [UIColor whiteColor];
    self.chatLogLabel.font = [UIFont systemFontOfSize:13];
    [self.contentView addSubview:self.chatLogLabel];
    
    // Thêm các thành phần giao diện khác như inputTextView, sendButton... tại đây
}

#pragma mark - Fix Thanh Trượt Xuống Đáy (Scroll to Bottom)

- (void)scrollToBottomAnimated:(BOOL)animated {
    // Đảm bảo layout đã được cập nhật xong trước khi tính toán chiều cao
    [self.view layoutIfNeeded];
    [self.contentView layoutIfNeeded];
    
    UIScrollView *scrollView = self.chatScrollView;
    if (!scrollView) return;
    
    // Tính toán khoảng cách tối đa cần trượt dựa trên tổng chiều cao nội dung và phần đệm bên dưới
    CGFloat contentHeight = self.chatLogLabel.frame.origin.y + self.chatLogLabel.frame.size.height + 20;
    
    // Cập nhật lại contentSize của scrollView nếu dùng custom layout
    scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, MAX(contentHeight, scrollView.bounds.size.height));
    
    CGFloat bottomOffset = scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.contentInset.bottom;
    if (bottomOffset > 0) {
        [scrollView setContentOffset:CGPointMake(0, bottomOffset) animated:animated];
    }
}

#pragma mark - AIStreamDelegate (Nhận dữ liệu từ AI & Tool)

- (void)aiStreamDidReceiveText:(NSString *)text {
    // Cập nhật nội dung tin nhắn mới vào giao diện chat
    NSString *currentText = self.chatLogLabel.text ?: @"";
    self.chatLogLabel.text = [NSString stringWithFormat:@"%@\n%@", currentText, text];
    
    // Tự động co giãn frame của label theo nội dung text
    CGSize size = [self.chatLogLabel sizeThatFits:CGSizeMake(self.chatScrollView.bounds.size.width - 24, CGFLOAT_MAX)];
    CGRect frame = self.chatLogLabel.frame;
    frame.size.height = size.height;
    self.chatLogLabel.frame = frame;
    
    self.contentView.frame = CGRectMake(0, 0, self.chatScrollView.bounds.size.width, MAX(size.height + 40, self.chatScrollView.bounds.size.height));
    
    // Đưa thanh trượt xuống đáy sau một khoảng trễ ngắn để đảm bảo render hoàn tất
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:YES];
    });
}

- (void)aiStreamDidComplete {
    // Hoàn tất quá trình phản hồi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:YES];
    });
}

- (void)aiStreamDidFailWithError:(NSError *)error {
    NSString *errStr = [NSString stringWithFormat:@"\n[Lỗi] %@", error.localizedDescription];
    self.chatLogLabel.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogLabel.text ?: @"", errStr];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:YES];
    });
}

- (void)aiDidCallTool:(NSString *)toolName args:(NSDictionary *)args result:(id)result {
    // Khi tool trả về kết quả, hiển thị và tự động trượt xuống đáy
    NSString *toolLog = [NSString stringWithFormat:@"\n[tool] %@ -> hoàn tất", toolName];
    self.chatLogLabel.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogLabel.text ?: @"", toolLog];
    
    CGSize size = [self.chatLogLabel sizeThatFits:CGSizeMake(self.chatScrollView.bounds.size.width - 24, CGFLOAT_MAX)];
    CGRect frame = self.chatLogLabel.frame;
    frame.size.height = size.height;
    self.chatLogLabel.frame = frame;
    self.contentView.frame = CGRectMake(0, 0, self.chatScrollView.bounds.size.width, MAX(size.height + 40, self.chatScrollView.bounds.size.height));
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:YES];
    });
}

@end
