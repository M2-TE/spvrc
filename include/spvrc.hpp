#pragma once
#include <string_view>
#include <cstdint>
#include <vector>

namespace spvrc {
    auto load(std::string_view path) -> std::vector<uint32_t>;
    auto inline load(const char* path) -> std::vector<uint32_t> {
        return load(std::string_view(path));
    }
}