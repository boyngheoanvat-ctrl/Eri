#import "MemoryVC.h"
#import "MemoryEditor.h"
#import "MemoryResult.h"
#import "ToolTheme.h"

@interface MemoryVC () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<MemoryResult *> *resultsList;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UITextField *editField;

@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.resultsList = [NSMutableArray array];
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    
    // Ô nhập giá trị tìm kiếm
    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(10, 10, w - 130, 36)];
    self.searchField.placeholder = @"Nhập giá trị cần tìm...";
    self.searchField.backgroundColor = [ToolTheme shared].surface;
    self.searchField.textColor = [ToolTheme shared].textPrimary;
    self.searchField.font = [[ToolTheme shared] monoFont:12];
    self.searchField.layer.borderWidth = 1;
    self.searchField.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.searchField.layer.cornerRadius = 4;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:self.searchField];
    
    // Nút Tìm kiếm
    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    searchBtn.frame = CGRectMake(w - 110, 10, 100, 36);
    searchBtn.backgroundColor = [ToolTheme shared].accent;
    [searchBtn setTitle:@"Tìm kiếm" forState:UIControlStateNormal];
    [searchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    searchBtn.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    searchBtn.layer.cornerRadius = 4;
    [searchBtn addTarget:self action:@selector(didTapSearch) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:searchBtn];
    
    // Bảng kết quả RAM (Đã bỏ hoàn toàn popup Min/Max)
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 56, w, CGRectGetHeight(self.view.bounds) - 56) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.tableView];
}

- (void)reload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)didTapSearch {
    NSString *query = self.searchField.text;
    if (query.length == 0) return;
    
    NSArray *found = [[MemoryEditor shared] searchValue:query type:MemValueTypeInt32 limit:500];
    [self.resultsList setArray:found];
    [self reload];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.resultsList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MemoryCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"MemoryCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [ToolTheme shared].success;
        cell.textLabel.font = [[ToolTheme shared] monoBoldFont:12];
        cell.detailTextLabel.textColor = [ToolTheme shared].textSecondary;
        cell.detailTextLabel.font = [[ToolTheme shared] monoFont:10];
    }
    
    MemoryResult *res = self.resultsList[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"0x%llX", (uint64_t)res.address];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Value: %@", res.stringValue];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
