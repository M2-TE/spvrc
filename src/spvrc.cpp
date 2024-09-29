#include <string_view>
#include <cstdint>
#include <vector>
#include "spvrc.hpp"
#include "/home/jan/repos/spvrc/build/shaders/example.comp.hpp"

// https://stackoverflow.com/a/46711735
constexpr uint32_t hash(std::string_view data) noexcept {
    uint32_t hash = 5381;
    for (const char &c : data) {
        hash = ((hash << 5) + hash) + static_cast<unsigned char>(c);
    }
    return hash;
}

namespace spvrc {
    auto load(std::string_view path) -> std::vector<uint32_t> {
        std::vector<uint32_t> data;
        switch (hash(path)) {
            case hash("example.comp"): data = { example_comp, example_comp + std::size(example_comp)}; break;
            default: break;
        }
        return data;
    }
}