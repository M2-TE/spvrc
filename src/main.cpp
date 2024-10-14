#include <spvrc/spvrc.hpp>
#include <iostream>
#include <string_view>

int main() {
    auto [arr, size] = spvrc::load("example.comp");
    std::cout << "data size: " << size << std::endl;
    return 0;
}