#import "MemoryVC.h"
#import "MemoryEditor.h"
#import "ToolTheme.h"

@interface MemoryVC () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UISegmentedControl *typeControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<MemoryResult *> *results;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) MemValueType currentType;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.results = [NSMutableArray array];
    self.currentType = MemValueTypeInt32;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    CGFloat y = 10;

    // Type selector
    NSArray *types = @[@"Int32", @"Int64", @"Float", @"Double"];
    self.typeControl = [[UISegmentedControl alloc] initWithItems:types];
    self.typeControl.frame = CGRectMake(10, y, w - 20, 32);
    self.typeControl.selectedSegmentIndex = 0;
    self.typeControl.backgroundColor = [ToolTheme shared].surface;
    self.typeControl.selectedSegmentTintColor = [ToolTheme shared].accent;
    [self.typeControl setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [[ToolTheme shared] monoFont:11]
    } forState:UIControlStateSelected];
    [self.typeControl addTarget:self action:@selector(typeChanged)
              forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.typeControl];
    y += 42;

    // Search field + button
    self.valueField = [[UITextField alloc] initWithFrame:CGRectMake(10, y, w - 90, 36)];
    self.valueField.backgroundColor = [ToolTheme shared].surface;
    self.valueField.textColor = [ToolTheme shared].textPrimary;
    self.valueField.font = [[ToolTheme shared] monoFont:12];
    self.valueField.layer.borderWidth = 1;
    self.valueField.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.valueField.layer.cornerRadius = 4;
    self.valueField.placeholder = @"Tim gia tri...";
    self.valueField.keyboardType = UIKeyboardTypeDecimalPad;
    self.valueField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 36)];
    self.valueField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:self.valueField];

    self.searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.searchButton.frame = CGRectMake(w - 76, y, 66, 36);
    self.searchButton.backgroundColor = [ToolTheme shared].accent;
    self.searchButton.layer.cornerRadius = 4;
    [self.searchButton setTitle:@"Tim" forState:UIControlStateNormal];
    [self.searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.searchButton.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    [self.searchButton addTarget:self action:@selector(searchTapped)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.searchButton];
    y += 46;

    // Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y, w - 20, 20)];
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].textMuted;
    self.statusLabel.font = [[ToolTheme shared] monoFont:10];
    [self.view addSubview:self.statusLabel];
    y += 24;

    // Table
    self.tableView = [[UITableView alloc] initWithFrame:
        CGRectMake(0, y, w, h - y)
                                                     style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [ToolTheme shared].background;
    self.tableView.separatorColor = [ToolTheme shared].divider;
    self.tableView.rowHeight = 44;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.view addSubview:self.tableView];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
        UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [ToolTheme shared].accent;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

- (void)typeChanged {
    NSInteger idx = self.typeControl.selectedSegmentIndex;
    if (idx == 0) self.currentType = MemValueTypeInt32;
    else if (idx == 1) self.currentType = MemValueTypeInt64;
    else if (idx == 2) self.currentType = MemValueTypeFloat;
    else if (idx == 3) self.currentType = MemValueTypeDouble;
}

- (void)searchTapped {
    NSString *value = self.valueField.text;
    if (value.length == 0) return;

    [self.view endEditing:YES];
    [self.results removeAllObjects];
    [self.tableView reloadData];
    self.statusLabel.text = @"Dang tim...";
    [self.spinner startAnimating];
    self.searchButton.enabled = NO;

    MemValueType type = self.currentType;
    __weak typeof(self) ws = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<MemoryResult *> *found = [[MemoryEditor shared]
            searchValue:value type:type limit:50];

        dispatch_async(dispatch_get_main_queue(), ^{
            [ws.results addObjectsFromArray:found];
            [ws.tableView reloadData];
            ws.statusLabel.text = [NSString stringWithFormat:@"Tim thay %lu ket qua",
                                    (unsigned long)found.count];
            [ws.spinner stopAnimating];
            ws.searchButton.enabled = YES;
        });
    });
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell" forIndexPath:ip];
    MemoryResult *r = self.results[ip.row];

    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];

    UILabel *addr = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 200, 16)];
    addr.text = [NSString stringWithFormat:@"0x%llX", (uint64_t)r.address];
    addr.textColor = [ToolTheme shared].accent;
    addr.font = [[ToolTheme shared] monoFont:11];
    [cell.contentView addSubview:addr];

    UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(10, 24, 200, 16)];
    val.text = [NSString stringWithFormat:@"Value: %@", r.stringValue];
    val.textColor = [ToolTheme shared].textPrimary;
    val.font = [[ToolTheme shared] monoFont:11];
    [cell.contentView addSubview:val];

    UILabel *edit = [[UILabel alloc] initWithFrame:CGRectMake(tv.bounds.size.width - 60, 14, 50, 16)];
    edit.text = @"Edit";
    edit.textColor = [ToolTheme shared].warning;
    edit.textAlignment = NSTextAlignmentRight;
    edit.font = [[ToolTheme shared] monoBoldFont:11];
    [cell.contentView addSubview:edit];

    cell.backgroundColor = [UIColor clearColor];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    MemoryResult *r = self.results[ip.row];
    [self showEditDialogFor:r];
}

- (void)showEditDialogFor:(MemoryResult *)r {
    NSString *title = [NSString stringWithFormat:@"0x%llX", (uint64_t)r.address];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                    message:@"Nhap gia tri moi"
                                                             preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Value";
        tf.text = r.stringValue;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Save"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *newVal = alert.textFields.firstObject.text;
        BOOL ok = [[MemoryEditor shared] writeValue:newVal at:r.address type:r.type];
        r.stringValue = newVal;
        [self.tableView reloadData];
        self.statusLabel.text = ok ? @"Sua thanh cong" : @"Sua that bai";
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reload {
    [self.tableView reloadData];
}

@end
