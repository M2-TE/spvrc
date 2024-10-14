#pragma once
#include <string_view>
#include <cstdint>
#include <vector>

namespace spvrc {
    auto load(std::string_view path) -> std::pair<const uint32_t*, std::size_t>;
    auto inline load(const char* path) -> std::pair<const uint32_t*, std::size_t> {
        return load(std::string_view(path));
    }
}