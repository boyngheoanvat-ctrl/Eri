#import <Foundation/Foundation.h>
#include <iostream>
#include <string>

// --- PHẦN C++ CLASS ---
class CppGreeter {
private:
    std::string name;
public:
    CppGreeter(const std::string& n) : name(n) {}
    
    void sayHello() {
        std::cout << "[C++] Xin chào, " << name << " từ thế giới C++ thuần túy!\n" << std::endl;
    }
};

// --- PHẦN OBJECTIVE-C & MAIN ---
int main(int argc, const char * argv[]) {
    // Sử dụng ARC (Automatic Reference Counting) của Objective-C
    @autoreleasepool {
        // 1. In thông báo bằng Objective-C
        NSLog(@"[Objective-C] Đang khởi chạy ứng dụng kết hợp Objective-C++...");
        
        // 2. Khởi tạo và sử dụng đối tượng C++
        CppGreeter greeter("Lập trình viên");
        greeter.sayHello();
        
        // 3. Sử dụng NSString và các tính năng của Foundation
        NSString *currentDate = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                               dateStyle:NSDateFormatterLongStyle
                                                               timeStyle:NSDateFormatterMediumStyle];
        
        NSLog(@"[Objective-C] Thời gian hệ thống hiện tại: %@", currentDate);
    }
    
    return 0;
}
