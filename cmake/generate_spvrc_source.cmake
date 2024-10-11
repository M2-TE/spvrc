string(REPLACE " " ";" SPVRC_SPIRV_HEADERS ${SPVRC_SPIRV_HEADERS})
string(REPLACE " " ";" SPVRC_SPIRV_FILES ${SPVRC_SPIRV_FILES})
string(REPLACE " " ";" SPVRC_SPIRV_SYMBOLS ${SPVRC_SPIRV_SYMBOLS})

file(WRITE "${SPVRC_SRC}"
"#include <string_view>
#include <cstdint>
#include <cassert>
#include <vector>
#include \"spvrc/spvrc.hpp\"
")
# include shader headers
foreach(HEADER_PATH ${SPVRC_SPIRV_HEADERS})
    file(APPEND "${SPVRC_SRC}" "#include \"${HEADER_PATH}\"\n")
endforeach(HEADER_PATH)
# add namespace and shader load function
file(APPEND "${SPVRC_SRC}" "
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
        switch (hash(path)) {"
)
# insert shader data
foreach(SPIRV_FILE SPIRV_SYMBOL IN ZIP_LISTS SPVRC_SPIRV_FILES SPVRC_SPIRV_SYMBOLS)
    file(APPEND "${SPVRC_SRC}" "
            case hash(\"${SPIRV_FILE}\"): data = { ${SPIRV_SYMBOL}, ${SPIRV_SYMBOL} + std::size(${SPIRV_SYMBOL})}; break;"
    )
endforeach(SPIRV_FILE SPIRV_SYMBOL)
# end namespace
file(APPEND "${SPVRC_SRC}" "
            default: assert(false && \"Shader not found\");
        }
        return data;
    }
}")