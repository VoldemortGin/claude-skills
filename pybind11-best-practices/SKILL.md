---
name: pybind11-best-practices
description: Guide for creating production-ready pybind11 C++/Python binding projects. Use when user wants to create a new pybind11 project, add Python bindings to C++ code, set up build systems for C++ extensions, or asks about pybind11 patterns like class bindings, NumPy integration, smart pointers, trampolines, STL containers, GIL management, or return value policies.
---

# pybind11 Best Practices

Production-ready engineering guide for pybind11 projects. Follow these patterns when creating or modifying pybind11-based C++/Python binding projects.

## Project Structure

```
my_project/
├── CMakeLists.txt
├── pyproject.toml
├── include/
│   └── my_library/          # Public C++ headers
│       ├── core.h
│       └── utils.h
├── src/
│   ├── my_library/          # C++ implementation
│   │   ├── core.cpp
│   │   └── utils.cpp
│   └── bindings/            # pybind11 bindings (SEPARATE from core C++)
│       ├── module.cpp        # PYBIND11_MODULE definition
│       ├── bind_core.cpp
│       └── bind_utils.cpp
├── python/
│   └── my_package/          # Pure Python wrapper
│       ├── __init__.py       # Re-exports from compiled _my_package
│       └── helpers.py
├── tests/
│   ├── conftest.py
│   ├── test_core.py
│   └── test_utils.py
└── .github/
    └── workflows/
        └── wheels.yml        # cibuildwheel CI
```

Key principles:
- Keep binding code in `src/bindings/`, separate from core C++ logic.
- Name the compiled extension with underscore prefix: `_my_package`.
- The Python package in `python/my_package/__init__.py` re-exports from the compiled module.

## Build System: scikit-build-core + CMake

scikit-build-core is the recommended build backend. It wraps CMake and produces correct wheels.

### pyproject.toml

```toml
[build-system]
requires = ["scikit-build-core>=0.11", "pybind11>=2.13"]
build-backend = "scikit_build_core.build"

[project]
name = "my-package"
version = "0.1.0"
description = "My pybind11 project"
requires-python = ">=3.10"
dependencies = []

[project.optional-dependencies]
test = ["pytest>=7.0"]
numpy = ["numpy"]

[tool.scikit-build]
cmake.build-type = "Release"
wheel.packages = ["python/my_package"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

Notes:
- `pybind11` goes in `build-system.requires` (build-time only), NOT `project.dependencies`.
- `wheel.packages` tells scikit-build-core where the Python package lives.
- scikit-build-core auto-downloads cmake/ninja if system versions are insufficient.

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.15...3.30)
project(
    ${SKBUILD_PROJECT_NAME}
    VERSION ${SKBUILD_PROJECT_VERSION}
    LANGUAGES CXX
)

set(PYBIND11_FINDPYTHON ON)
find_package(pybind11 CONFIG REQUIRED)

# Option A: small project — compile everything into the extension
pybind11_add_module(_my_package
    src/bindings/module.cpp
    src/bindings/bind_core.cpp
    src/my_library/core.cpp
)
target_compile_features(_my_package PRIVATE cxx_std_17)
target_include_directories(_my_package PRIVATE include)
install(TARGETS _my_package DESTINATION my_package)
```

For larger projects, build a static library and link:

```cmake
add_library(my_library STATIC
    src/my_library/core.cpp
    src/my_library/utils.cpp
)
target_include_directories(my_library PUBLIC include)
target_compile_features(my_library PUBLIC cxx_std_17)

pybind11_add_module(_my_package
    src/bindings/module.cpp
    src/bindings/bind_core.cpp
    src/bindings/bind_utils.cpp
)
target_link_libraries(_my_package PRIVATE my_library)
install(TARGETS _my_package DESTINATION my_package)
```

Key points:
- Use `LANGUAGES CXX` to skip unnecessary C compiler search.
- `set(PYBIND11_FINDPYTHON ON)` for reliable Python discovery.
- `pybind11_add_module` handles platform-specific extension details.

## Binding Patterns

### Module Definition

```cpp
#include <pybind11/pybind11.h>
namespace py = pybind11;

// Forward declarations for bindings defined in other files
void bind_core(py::module_& m);
void bind_utils(py::module_& m);

PYBIND11_MODULE(_my_package, m) {
    m.doc() = "My C++ extension module";
    bind_core(m);
    bind_utils(m);
}
```

### Class Bindings

```cpp
#include <pybind11/pybind11.h>
namespace py = pybind11;

struct Pet {
    std::string name;
    int age;
    Pet(const std::string& name, int age) : name(name), age(age) {}
    std::string greet() const { return "Hello, I am " + name; }
};

void bind_core(py::module_& m) {
    py::class_<Pet>(m, "Pet")
        .def(py::init<const std::string&, int>(),
             py::arg("name"), py::arg("age"))
        .def("greet", &Pet::greet)
        .def_readwrite("name", &Pet::name)
        .def_readonly("age", &Pet::age)
        .def("__repr__", [](const Pet& p) {
            return "<Pet name='" + p.name + "' age=" + std::to_string(p.age) + ">";
        });
}
```

### STL Containers

```cpp
#include <pybind11/stl.h>  // Auto-converts std::vector, std::map, etc.

// WARNING: stl.h always COPIES data at the boundary.
// Modifications to C++ containers are NOT visible in Python.

// For zero-copy / in-place modification, use opaque bindings:
#include <pybind11/stl_bind.h>
PYBIND11_MAKE_OPAQUE(std::vector<int>)

void bind_containers(py::module_& m) {
    py::bind_vector<std::vector<int>>(m, "VectorInt");
}
```

`PYBIND11_MAKE_OPAQUE` must appear in every compilation unit before any usage.

### NumPy Support

```cpp
#include <pybind11/numpy.h>

m.def("sum_array", [](py::array_t<double> input) {
    auto buf = input.request();
    if (buf.ndim != 1)
        throw std::runtime_error("Expected 1-D array");
    double* ptr = static_cast<double*>(buf.ptr);
    double sum = 0;
    for (ssize_t i = 0; i < buf.size; i++)
        sum += ptr[i];
    return sum;
});

// High-performance unchecked access (skip bounds checking in inner loops)
m.def("sum_2d", [](py::array_t<double> x) {
    auto r = x.unchecked<2>();
    double sum = 0;
    for (py::ssize_t i = 0; i < r.shape(0); i++)
        for (py::ssize_t j = 0; j < r.shape(1); j++)
            sum += r(i, j);
    return sum;
});

// Enforce C-contiguous layout
m.def("process", [](py::array_t<double, py::array::c_style | py::array::forcecast> arr) {
    // Guaranteed C-contiguous double array
});

// Vectorize a scalar function
double my_func(int x, float y, double z);
m.def("vectorized_func", py::vectorize(my_func));
```

### Smart Pointers

```cpp
// std::shared_ptr as holder
py::class_<MyClass, std::shared_ptr<MyClass>>(m, "MyClass")
    .def(py::init<>());

// Factory returning shared_ptr
m.def("create", []() { return std::make_shared<MyClass>(); });
```

Never mix raw pointers with smart pointer holders — returning a raw pointer when the holder is `shared_ptr` can cause double-free.

### Virtual Functions / Trampolines

```cpp
class Animal {
public:
    virtual ~Animal() = default;
    virtual std::string go(int n_times) = 0;
};

// Trampoline: enables Python subclasses to override C++ virtuals
class PyAnimal : public Animal {
public:
    using Animal::Animal;
    std::string go(int n_times) override {
        PYBIND11_OVERRIDE_PURE(std::string, Animal, go, n_times);
    }
};

py::class_<Animal, PyAnimal>(m, "Animal")
    .def(py::init<>())
    .def("go", &Animal::go);  // Bind against Animal, NOT PyAnimal
```

Use `PYBIND11_OVERRIDE_PURE` for pure virtual, `PYBIND11_OVERRIDE` for virtual with default.

## Error Handling

pybind11 auto-maps common C++ exceptions:

| C++ Exception | Python Exception |
|---|---|
| `std::invalid_argument` | `ValueError` |
| `std::out_of_range` | `IndexError` |
| `std::bad_alloc` | `MemoryError` |
| `std::domain_error` | `ValueError` |
| `std::overflow_error` | `OverflowError` |
| `std::exception` | `RuntimeError` |

Custom exception:

```cpp
static py::exception<MyCustomError> exc(m, "MyCustomError");

// Or with translator
py::register_local_exception_translator([](std::exception_ptr p) {
    try {
        if (p) std::rethrow_exception(p);
    } catch (const MyError& e) {
        py::set_error(PyExc_ValueError, e.what());
    }
});
```

Every `catch` clause MUST call `py::set_error()` — failing to do so crashes Python.

## Return Value Policies

| Policy | Use Case |
|---|---|
| `automatic` (default) | General use |
| `reference_internal` | Returning member data from methods |
| `reference` | Global/static data managed by C++ |
| `copy` | When an independent copy is needed |
| `move` | Rvalue returns (preferred over copy) |
| `take_ownership` | Python should own and delete the object |

```cpp
// Return reference to internal data, keep parent alive
m.def("get_data", [](const Obj& o) -> const std::vector<double>& {
    return o.data();
}, py::return_value_policy::reference_internal);
```

## GIL Management

- GIL is held by default when Python calls C++. Release it for long computations:

```cpp
m.def("heavy_compute", &heavy_compute,
      py::call_guard<py::gil_scoped_release>());
```

- Never create global/static `py::object` variables.
- Destructors that wait on threads needing the GIL will deadlock.
- When C++ calls Python callbacks, pybind11 auto-acquires the GIL.

## Testing

Pair each binding file with a pytest file:

```python
import pytest
from my_package import _my_package

def test_pet_creation():
    pet = _my_package.Pet("Fido", 3)
    assert pet.name == "Fido"
    assert pet.age == 3

def test_invalid_input():
    with pytest.raises(TypeError):
        _my_package.Pet(123, "not_an_int")

def test_numpy_sum():
    import numpy as np
    arr = np.array([1.0, 2.0, 3.0])
    assert _my_package.sum_array(arr) == pytest.approx(6.0)
```

## Development Workflow

```bash
# Editable install for iterative development
pip install -e . --no-build-isolation

# Run tests
pytest tests/
```

In `pyproject.toml` for editable mode:

```toml
[tool.scikit-build]
editable.mode = "redirect"
editable.rebuild = true
```

## Packaging: cibuildwheel CI

```yaml
# .github/workflows/wheels.yml
name: Build wheels
on:
  push:
    tags: ["v*"]

jobs:
  build_wheels:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: pypa/cibuildwheel@v2.21
      - uses: actions/upload-artifact@v4
        with:
          name: wheels-${{ matrix.os }}
          path: ./wheelhouse/*.whl
```

Configure in `pyproject.toml`:

```toml
[tool.cibuildwheel]
test-command = "pytest {project}/tests"
test-requires = ["pytest"]
skip = ["pp*", "*-musllinux*"]

[tool.cibuildwheel.macos]
archs = ["x86_64", "arm64"]
```
