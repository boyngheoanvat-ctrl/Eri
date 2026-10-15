#import "MemoryVC.h"
#import "ToolTheme.h"

@interface MemoryVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *editAllButton;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UITextView *resultTextView;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    // 1. Phân loại kiểu dữ liệu (Segmented Control lọc type)
    NSArray *types = @[@"DWORD", @"Float", @"Double", @"Qword", @"Hex"];
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:types];
    self.typeSegment.frame = CGRectMake(16, 16, w - 32, 30);
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.typeSegment];
    
    // 2. Ô nhập giá trị tìm kiếm
    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, 56, w - 170, 36)];
    self.searchField.placeholder = @"Nhập giá trị (vd: 100, 0x5F)...";
    self.searchField.backgroundColor = [ToolTheme shared].surface;
    self.searchField.textColor = [ToolTheme shared].textPrimary;
    self.searchField.font = [[ToolTheme shared] monoFont:12];
    self.searchField.layer.cornerRadius = 4;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchField];
    
    // 3. Nút Tìm kiếm
    self.searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.searchButton.frame = CGRectMake(w - 146, 56, 60, 36);
    self.searchButton.backgroundColor = [ToolTheme shared].accent;
    [self.searchButton setTitle:@"Tìm" forState:UIControlStateNormal];
    [self.searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.searchButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.searchButton.layer.cornerRadius = 4;
    self.searchButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.searchButton addTarget:self action:@selector(didTapSearch) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.searchButton];
    
    // 4. Nút Edit All (Sửa tất cả kết quả tìm được)
    self.editAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.editAllButton.frame = CGRectMake(w - 78, 56, 62, 36);
    self.editAllButton.backgroundColor = [ToolTheme shared].warning;
    [self.editAllButton setTitle:@"Edit All" forState:UIControlStateNormal];
    [self.editAllButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.editAllButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.editAllButton.layer.cornerRadius = 4;
    self.editAllButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.editAllButton addTarget:self action:@selector(didTapEditAll) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.editAllButton];
    
    // 5. Khung hiển thị kết quả bộ nhớ
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 104, w - 32, h - 120)];
    self.resultTextView.backgroundColor = [ToolTheme shared].surface;
    self.resultTextView.textColor = [ToolTheme shared].textSecondary;
    self.resultTextView.font = [[ToolTheme shared] monoFont:11];
    self.resultTextView.text = @"-- Memory Scanner Ready --\n";
    self.resultTextView.editable = NO;
    self.resultTextView.layer.cornerRadius = 6;
    self.resultTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.resultTextView];
}

- (void)didTapSearch {
    NSString *val = self.searchField.text;
    if (val.length == 0) return;
    self.resultTextView.text = [self.resultTextView.text stringByAppendingFormat:@"\n[Scan] Đang quét giá trị: %@...", val];
}

- (void)didTapEditAll {
    self.resultTextView.text = [self.resultTextView.text stringByAppendingString:@"\n[Edit] Đã áp dụng thay đổi trên toàn bộ kết quả tìm kiếm."];
}

- (void)reload {
    self.resultTextView.text = @"-- Memory Scanner Ready --\n";
}

@end
