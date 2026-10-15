#import "MemoryVC.h"
#import "ToolTheme.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>

@interface MemoryVC () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIButton *editAllButton;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *foundAddresses;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.foundAddresses = [NSMutableArray array];
    
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    NSArray *types = @[@"DWORD", @"Float", @"Double", @"Qword", @"Hex"];
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:types];
    self.typeSegment.frame = CGRectMake(16, 16, w - 32, 30);
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.typeSegment];
    
    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, 58, w - 232, 36)];
    self.searchField.placeholder = @"Nhập giá trị thực tế (vd: 13934)...";
    self.searchField.backgroundColor = [ToolTheme shared].surface;
    self.searchField.textColor = [ToolTheme shared].textPrimary;
    self.searchField.font = [[ToolTheme shared] monoFont:12];
    self.searchField.layer.cornerRadius = 4;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 36)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchField];
    
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
    
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 106, w - 32, h - 122)];
    self.resultTextView.backgroundColor = [ToolTheme shared].surface;
    self.resultTextView.textColor = [ToolTheme shared].textSecondary;
    self.resultTextView.font = [[ToolTheme shared] monoFont:11];
    self.resultTextView.text = @"-- Real Memory Scanner Ready --\n[Info] Sẵn sàng quét vùng nhớ Mach Task thực tế.";
    self.resultTextView.editable = NO;
    self.resultTextView.layer.cornerRadius = 6;
    self.resultTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.resultTextView];
}

- (void)didTapSearch {
    NSString *valStr = self.searchField.text;
    if (valStr.length == 0) return;
    int targetVal = [valStr intValue];
    
    [self.foundAddresses removeAllObjects];
    NSMutableString *log = [NSMutableString stringWithFormat:@"[Scan] Đang quét bộ nhớ thực cho giá trị: %d\n", targetVal];
    
    mach_port_t task = mach_task_self();
    vm_address_t address = 0x100000000;
    vm_size_t size = 0;
    natural_t depth = 1;
    
    while (1) {
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t kr = vm_region_recurse_64(task, &address, &size, &depth, (vm_region_info_t)&info, &count);
        if (kr != KERN_SUCCESS) break;
        
        if (info.is_submap) {
            depth++;
            continue;
        }
        
        if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE) && !(info.share_mode == SM_SHARED)) {
            int *buffer = (int *)malloc(size);
            vm_size_t outSize = (vm_size_t)size;
            if (vm_read_overwrite(task, address, size, (vm_address_t)buffer, &outSize) == KERN_SUCCESS) {
                for (size_t i = 0; i < outSize / sizeof(int); i++) {
                    if (buffer[i] == targetVal) {
                        uint64_t foundAddr = address + (i * sizeof(int));
                        [self.foundAddresses addObject:@(foundAddr)];
                        if (self.foundAddresses.count <= 20) {
                            [log appendFormat:@"Found at: 0x%llX -> Value: %d\n", foundAddr, buffer[i]];
                        }
                    }
                }
            }
            free(buffer);
            if (self.foundAddresses.count > 1000) break;
        }
        address += size;
    }
    
    [log appendFormat:@"\n[Scan Complete] Tổng số địa chỉ tìm thấy: %lu", (unsigned long)self.foundAddresses.count];
    self.resultTextView.text = log;
}

- (void)didTapFilter {
    NSString *valStr = self.searchField.text;
    if (valStr.length == 0 || self.foundAddresses.count == 0) return;
    int targetVal = [valStr intValue];
    
    mach_port_t task = mach_task_self();
    NSMutableArray *survived = [NSMutableArray array];
    NSMutableString *log = [NSMutableString stringWithFormat:@"[Filter] Lọc lại giá trị: %d\n", targetVal];
    
    for (NSNumber *numAddr in self.foundAddresses) {
        uint64_t addr = [numAddr unsignedLongLongValue];
        int val = 0;
        vm_size_t size = sizeof(int);
        if (vm_read_overwrite(task, (vm_address_t)addr, sizeof(int), (vm_address_t)&val, &size) == KERN_SUCCESS) {
            if (val == targetVal) {
                [survived addObject:numAddr];
                [log appendFormat:@"Keep: 0x%llX -> Value: %d\n", addr, val];
            }
        }
    }
    self.foundAddresses = survived;
    [log appendFormat:@"\n[Filter Complete] Còn lại: %lu địa chỉ", (unsigned long)self.foundAddresses.count];
    self.resultTextView.text = log;
}

- (void)didTapEditAll {
    NSString *valStr = self.searchField.text;
    if (valStr.length == 0 || self.foundAddresses.count == 0) return;
    int newVal = [valStr intValue];
    
    mach_port_t task = mach_task_self();
    int count = 0;
    
    for (NSNumber *numAddr in self.foundAddresses) {
        uint64_t addr = [numAddr unsignedLongLongValue];
        vm_protect(task, (vm_address_t)addr, sizeof(int), FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        kern_return_t kr = vm_write(task, (vm_address_t)addr, (vm_offset_t)&newVal, sizeof(int));
        if (kr == KERN_SUCCESS) count++;
    }
    
    self.resultTextView.text = [self.resultTextView.text stringByAppendingFormat:@"\n[Edit All] Đã ghi đè thành công giá trị %d vào %d địa chỉ thực tế!", newVal, count];
}

- (void)reload {
    self.resultTextView.text = @"-- Real Memory Scanner Ready --\n";
}

@end
