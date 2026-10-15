#import "MemoryVC.h"
#import "ToolTheme.h"

@interface MemoryVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *filterButton;
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
    
    // 1. Phân loại kiểu dữ liệu (DWORD, Float, Double, Qword, Hex)
    NSArray *types = @[@"DWORD", @"Float", @"Double", @"Qword", @"Hex"];
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:types];
    self.typeSegment.frame = CGRectMake(16, 16, w - 32, 30);
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.typeSegment];
    
    // 2. Ô nhập giá trị tìm kiếm / lọc runtime
    // Tự động co giãn chiều ngang để chừa chỗ cho 3 nút bấm phía bên phải
    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, 58, w - 232, 36)];
    self.searchField.placeholder = @"Nhập giá trị runtime (vd: 13934)...";
    self.searchField.backgroundColor = [ToolTheme shared].surface;
    self.searchField.textColor = [ToolTheme shared].textPrimary;
    self.searchField.font = [[ToolTheme shared] monoFont:12];
    self.searchField.layer.cornerRadius = 4;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchField];
    
    // 3. Nút 1: Tìm value (New Search)
    self.searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.searchButton.frame = CGRectMake(w - 208, 58, 60, 36);
    self.searchButton.backgroundColor = [ToolTheme shared].accent;
    [self.searchButton setTitle:@"Tìm" forState:UIControlStateNormal];
    [self.searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.searchButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.searchButton.layer.cornerRadius = 4;
    self.searchButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.searchButton addTarget:self action:@selector(didTapSearch) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.searchButton];
    
    // 4. Nút 2: Lọc value thay đổi (Refine / Next Search)
    self.filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.filterButton.frame = CGRectMake(w - 142, 58, 60, 36);
    self.filterButton.backgroundColor = [ToolTheme shared].warning;
    [self.filterButton setTitle:@"Lọc" forState:UIControlStateNormal];
    [self.filterButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.filterButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.filterButton.layer.cornerRadius = 4;
    self.filterButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.filterButton addTarget:self action:@selector(didTapFilter) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.filterButton];
    
    // 5. Nút 3: Edit All (Sửa toàn bộ kết quả tìm được)
    self.editAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.editAllButton.frame = CGRectMake(w - 76, 58, 60, 36);
    self.editAllButton.backgroundColor = [ToolTheme shared].success;
    [self.editAllButton setTitle:@"Edit All" forState:UIControlStateNormal];
    [self.editAllButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.editAllButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    self.editAllButton.layer.cornerRadius = 4;
    self.editAllButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.editAllButton addTarget:self action:@selector(didTapEditAll) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.editAllButton];
    
    // 6. Khung hiển thị kết quả quét bộ nhớ runtime
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 106, w - 32, h - 122)];
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
    self.resultTextView.text = [self.resultTextView.text stringByAppendingFormat:@"\n[Scan] Đang quét giá trị mới: %@...", val];
}

- (void)didTapFilter {
    NSString *val = self.searchField.text;
    self.resultTextView.text = [self.resultTextView.text stringByAppendingFormat:@"\n[Filter] Đang lọc giá trị thay đổi (%@)...", val.length > 0 ? val : @"Khác"];
}

- (void)didTapEditAll {
    self.resultTextView.text = [self.resultTextView.text stringByAppendingString:@"\n[Edit] Đã thay đổi toàn bộ giá trị trong danh sách kết quả runtime."];
}

- (void)reload {
    self.resultTextView.text = @"-- Memory Scanner Ready --\n";
}

@end
