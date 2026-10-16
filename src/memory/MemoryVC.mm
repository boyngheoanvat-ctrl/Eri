#import "MemoryVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"
#import <mach/mach.h>

@interface MemoryVC () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UISegmentedControl *typeSelector;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *refineButton;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UITableView *resultsTable;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *foundAddresses;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.foundAddresses = [NSMutableArray array];
    [self buildUI];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat y = 16;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"Memory Scanner";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 36;

        self.typeSelector = [[UISegmentedControl alloc] initWithItems:@[@"Dword (I32)", @"Float", @"Double"]];
        self.typeSelector.frame = CGRectMake(16, y, w - 32, 32);
        self.typeSelector.selectedSegmentIndex = 0;
        [self.typeSelector setTintColor:[ToolTheme shared].accent];
        [self.view addSubview:self.typeSelector];
        y += 42;

        self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
        self.searchField.placeholder = @"Nhập giá trị cần tìm (vd: 100, 9999)...";
        self.searchField.backgroundColor = [ToolTheme shared].surface;
        self.searchField.textColor = [ToolTheme shared].textPrimary;
        self.searchField.font = [[ToolTheme shared] monoFont:12];
        self.searchField.layer.cornerRadius = 6;
        self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
        self.searchField.leftViewMode = UITextFieldViewModeAlways;
        self.searchField.delegate = self;
        [self.view addSubview:self.searchField];
        y += 50;

        CGFloat btnW = (w - 44) / 3.0;
        self.searchButton = [self makeButton:@"1. Tìm (Search)" frame:CGRectMake(16, y, btnW, 40) action:@selector(didTapNewSearch)];
        self.refineButton = [self makeButton:@"2. Lọc (Refine)" frame:CGRectMake(24 + btnW, y, btnW, 40) action:@selector(didTapRefine)];
        self.editButton   = [self makeButton:@"3. Sửa (Edit)"   frame:CGRectMake(32 + btnW * 2, y, btnW, 40) action:@selector(didTapEditAll)];
        [self.view addSubview:self.searchButton];
        [self.view addSubview:self.refineButton];
        [self.view addSubview:self.editButton];
        y += 50;

        self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 20)];
        self.statusLabel.text = @"Tìm thấy: 0 kết quả";
        self.statusLabel.textColor = [ToolTheme shared].textMuted;
        self.statusLabel.font = [[ToolTheme shared] monoFont:11];
        [self.view addSubview:self.statusLabel];
        y += 26;

        CGFloat tableH = CGRectGetHeight(self.view.bounds) - y - 16;
        self.resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(16, y, w - 32, MAX(120, tableH)) style:UITableViewStylePlain];
        self.resultsTable.backgroundColor = [ToolTheme shared].surface;
        self.resultsTable.layer.cornerRadius = 6;
        self.resultsTable.dataSource = self;
        self.resultsTable.delegate = self;
        [self.view addSubview:self.resultsTable];
    }
}

- (UIButton *)makeButton:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    btn.backgroundColor = [ToolTheme shared].accent;
    btn.layer.cornerRadius = 6;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

// Quét bộ nhớ thật thực tế qua vm_region và vm_read_overwrite
- (void)didTapNewSearch {
    @autoreleasepool {
        NSString *valStr = self.searchField.text;
        if (valStr.length == 0) return;
        [self.searchField resignFirstResponder];
        [self.foundAddresses removeAllObjects];

        int targetVal = valStr.intValue;
        mach_port_t task = mach_task_self();
        vm_address_t address = 0;
        vm_size_t size = 0;
        mach_msg_type_number_t infoCnt = VM_REGION_BASIC_INFO_COUNT_64;
        vm_region_basic_info_data_64_t info;
        mach_port_t object_name;

        int maxResults = 50; // Giới hạn kết quả tìm kiếm thực tế để mượt mà
        while (1) {
            kern_return_t kr = vm_region_64(task, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCnt, &object_name);
            if (kr != KERN_SUCCESS) break;

            if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE) && !(info.inheritance == VM_INHERIT_SHARE)) {
                vm_address_t cur = address;
                vm_address_t end = address + size;
                // Quét từng khối memory hợp lệ
                while (cur < end - sizeof(int)) {
                    int readVal = 0;
                    vm_size_t outSize = 0;
                    kern_return_t readKr = vm_read_overwrite(task, cur, sizeof(int), (vm_address_t)&readVal, &outSize);
                    if (readKr == KERN_SUCCESS && readVal == targetVal) {
                        [self.foundAddresses addObject:@{
                            @"address": [NSString stringWithFormat:@"%p", (void*)cur],
                            @"value": [NSString stringWithFormat:@"%d", readVal]
                        }];
                        if (self.foundAddresses.count >= maxResults) break;
                    }
                    cur += 4; // Bước nhảy 4 bytes cho Dword
                }
            }
            if (self.foundAddresses.count >= maxResults) break;
            address += size;
        }

        self.statusLabel.text = [NSString stringWithFormat:@"Tìm thấy: %lu kết quả thực tế", (unsigned long)self.foundAddresses.count];
        [self.resultsTable reloadData];
    }
}

- (void)didTapRefine {
    @autoreleasepool {
        NSString *valStr = self.searchField.text;
        if (valStr.length == 0 || self.foundAddresses.count == 0) return;
        [self.searchField resignFirstResponder];

        int targetVal = valStr.intValue;
        NSMutableArray *filtered = [NSMutableArray array];
        mach_port_t task = mach_task_self();

        for (NSDictionary *item in self.foundAddresses) {
            uintptr_t addr = strtoull([item[@"address"] UTF8String], NULL, 16);
            int readVal = 0;
            vm_size_t outSize = 0;
            kern_return_t readKr = vm_read_overwrite(task, addr, sizeof(int), (vm_address_t)&readVal, &outSize);
            if (readKr == KERN_SUCCESS && readVal == targetVal) {
                [filtered addObject:@{
                    @"address": item[@"address"],
                    @"value": [NSString stringWithFormat:@"%d", readVal]
                }];
            }
        }
        self.foundAddresses = filtered;
        self.statusLabel.text = [NSString stringWithFormat:@"Lọc còn lại: %lu kết quả", (unsigned long)self.foundAddresses.count];
        [self.resultsTable reloadData];
    }
}

- (void)didTapEditAll {
    @autoreleasepool {
        NSString *newValStr = self.searchField.text;
        if (newValStr.length == 0 || self.foundAddresses.count == 0) return;
        [self.searchField resignFirstResponder];

        int newVal = newValStr.intValue;
        mach_port_t task = mach_task_self();

        for (NSDictionary *item in self.foundAddresses) {
            uintptr_t addr = strtoull([item[@"address"] UTF8String], NULL, 16);
            vm_prot_t oldProt;
            kern_return_t kr = vm_protect(task, addr & ~(vm_page_size - 1), vm_page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            if (kr == KERN_SUCCESS) {
                *(int *)addr = newVal;
                vm_protect(task, addr & ~(vm_page_size - 1), vm_page_size, FALSE, oldProt);
            }
        }

        // Cập nhật lại giá trị hiển thị trên UI
        NSMutableArray *updatedList = [NSMutableArray array];
        for (NSDictionary *item in self.foundAddresses) {
            [updatedList addObject:@{
                @"address": item[@"address"],
                @"value": newValStr
            }];
        }
        self.foundAddresses = updatedList;
        [self.resultsTable reloadData];
        self.statusLabel.text = [NSString stringWithFormat:@"Đã ghi đè thành công giá trị: %@", newValStr];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.foundAddresses.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MemCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MemCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [[ToolTheme shared] monoFont:11];
        cell.textLabel.textColor = [ToolTheme shared].textPrimary;
        cell.detailTextLabel.font = [[ToolTheme shared] monoBoldFont:11];
        cell.detailTextLabel.textColor = [ToolTheme shared].accent;
    }
    NSDictionary *item = self.foundAddresses[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"Addr: %@", item[@"address"]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Val: %@", item[@"value"]];
    return cell;
}

- (void)reload {}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }

@end
