#include <spvrc/spvrc.hpp>
#include <iostream>
#include <string_view>

int main() {
    auto data = spvrc::load("example.comp");
    std::cout << "data.size() = " << data.size() << std::endl;
    return 0;
}