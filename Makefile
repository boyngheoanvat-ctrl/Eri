CXX = clang++
CXXFLAGS = -x objective-c++ -std=c++17 -fobjc-arc
LDFLAGS = -framework Foundation -framework UIKit

TARGET = libautodance.dylib
SRC = main.mm

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) -dynamiclib $(CXXFLAGS) $(SRC) $(LDFLAGS) -o $(TARGET)

clean:
	rm -f $(TARGET)
