CXX = clang++
# Các flags bắt buộc để hỗ trợ Objective-C, ARC và liên kết với Foundation framework
CXXFLAGS = -x objective-c++ -std=c++17 -fobjc-arc
LDFLAGS = -framework Foundation -framework UIKit -lsubstrate

TARGET = main_app
SRC = main.mm

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) $(LDFLAGS) -o $(TARGET)

clean:
	rm -f $(TARGET)

run: all
	./$(TARGET)
