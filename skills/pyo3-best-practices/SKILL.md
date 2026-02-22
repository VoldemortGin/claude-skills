---
name: pyo3-best-practices
description: Guide for creating production-ready PyO3 Rust-Python binding projects. Use when user wants to create a new PyO3 project, write Rust extensions for Python, set up maturin builds, or asks about PyO3 patterns like pyclass, pymethods, NumPy integration, async support, GIL management, type conversions, error handling, or cross-compilation with maturin.
---

# PyO3 Best Practices

Production-ready engineering guide for PyO3 (Rust-Python bindings) projects. Follow these patterns when creating or modifying PyO3-based projects.

## Project Structure

Use the mixed Rust/Python layout (created with `maturin new --mixed`):

```
my_project/
├── Cargo.toml
├── pyproject.toml
├── python/
│   └── my_project/
│       ├── __init__.py        # Re-exports from compiled Rust module
│       ├── py.typed           # PEP 561 marker
│       └── _internal.pyi     # Type stubs for Rust module
├── src/
│   ├── lib.rs                 # #[pymodule] entry point
│   ├── types.rs               # #[pyclass] definitions
│   ├── functions.rs           # #[pyfunction] definitions
│   └── errors.rs              # Custom error/exception types
├── tests/
│   ├── conftest.py
│   └── test_basic.py
└── Cargo.lock
```

Key principles:
- Keep Rust bindings in `src/`, pure Python wrappers in `python/`.
- Set `python-source = "python"` in `pyproject.toml` for the mixed layout.
- Name the compiled module with underscore prefix (`_internal`) and re-export in `__init__.py`.

## Build System: Maturin

Maturin is the officially recommended build tool. It handles wheel building, manylinux, ABI3, and cross-compilation.

### Cargo.toml

```toml
[package]
name = "my-project"
version = "0.1.0"
edition = "2021"

[lib]
name = "my_project"
crate-type = ["cdylib"]    # Required for Python extension

[dependencies]
pyo3 = { version = "0.28", features = ["extension-module"] }

# For ABI3 (one wheel works across Python versions):
# pyo3 = { version = "0.28", features = ["abi3-py310"] }

# For numpy:
# numpy = "0.28"

# For async:
# pyo3-async-runtimes = { version = "0.28", features = ["tokio-runtime"] }
# tokio = { version = "1", features = ["full"] }

[profile.release]
lto = true
codegen-units = 1
strip = true
```

Notes:
- `crate-type = ["cdylib"]` is mandatory. Add `"rlib"` only if you need the crate from other Rust code.
- `abi3-py3X` generates a single wheel for Python >= 3.X via the stable ABI.
- As of PyO3 0.27+, maturin >= 1.9.4 sets `PYO3_BUILD_EXTENSION_MODULE` automatically, so the `extension-module` feature is becoming optional.

### pyproject.toml

```toml
[build-system]
requires = ["maturin>=1.0,<2.0"]
build-backend = "maturin"

[project]
name = "my-project"
version = "0.1.0"
description = "A fast Python extension written in Rust"
requires-python = ">=3.10"

[project.optional-dependencies]
dev = ["pytest>=7", "numpy>=1.24"]

[tool.maturin]
python-source = "python"
features = ["pyo3/extension-module"]
profile = "release"
strip = true
module-name = "my_project._internal"

[tool.pytest.ini_options]
testpaths = ["tests"]
```

## Binding Patterns

### Module Definition

```rust
use pyo3::prelude::*;

#[pymodule]
mod my_project {
    use super::*;

    #[pymodule_export]
    use super::Point;

    #[pyfunction]
    fn add(a: i64, b: i64) -> i64 {
        a + b
    }

    #[pymodule]
    mod utils {
        use super::*;

        #[pyfunction]
        fn helper() -> String {
            "hello".to_string()
        }
    }
}
```

### Class Bindings

```rust
use pyo3::prelude::*;

#[pyclass]
struct Point {
    #[pyo3(get, set)]
    x: f64,
    #[pyo3(get)]           // read-only
    y: f64,
    label: Option<String>, // private, no auto accessor
}

#[pymethods]
impl Point {
    #[new]
    #[pyo3(signature = (x, y, label=None))]
    fn new(x: f64, y: f64, label: Option<String>) -> Self {
        Point { x, y, label }
    }

    #[getter]
    fn label(&self) -> Option<&str> {
        self.label.as_deref()
    }

    #[setter]
    fn set_label(&mut self, label: Option<String>) {
        self.label = label;
    }

    fn distance(&self, other: &Point) -> f64 {
        ((self.x - other.x).powi(2) + (self.y - other.y).powi(2)).sqrt()
    }

    #[staticmethod]
    fn origin() -> Point {
        Point { x: 0.0, y: 0.0, label: None }
    }

    #[classmethod]
    fn from_tuple(_cls: &Bound<'_, PyType>, coords: (f64, f64)) -> Self {
        Point { x: coords.0, y: coords.1, label: None }
    }

    fn __repr__(&self) -> String {
        format!("Point({}, {})", self.x, self.y)
    }
}
```

Note: `#[new]` combines `__new__` + `__init__`. There is no separate `__init__` in PyO3.

### Inheritance

```rust
#[pyclass(subclass)]
struct Animal {
    name: String,
}

#[pyclass(extends=Animal)]
struct Dog {
    breed: String,
}

#[pymethods]
impl Dog {
    #[new]
    fn new(name: String, breed: String) -> (Self, Animal) {
        (Dog { breed }, Animal { name })
    }
}
```

## Type Conversions

### Built-in Conversions

| Rust Type | Python Type |
|-----------|-------------|
| `bool` | `bool` |
| `i32, i64, u32, u64` | `int` |
| `f32, f64` | `float` |
| `String, &str` | `str` |
| `Vec<T>` | `list` |
| `HashMap<K, V>` | `dict` |
| `HashSet<T>` | `set` |
| `(A, B, ...)` | `tuple` |
| `Option<T>` | `Optional[T]` |
| `Bound<'py, PyAny>` | any Python object |
| `Py<T>` | owned reference (GIL-independent) |

### Custom FromPyObject / IntoPyObject

```rust
use pyo3::prelude::*;

#[derive(FromPyObject)]
struct Config {
    host: String,
    port: u16,
    #[pyo3(attribute("verbose"))]
    debug: bool,
}

// Enum extraction: tries each variant in order
#[derive(FromPyObject)]
enum StringOrInt {
    String(String),
    Int(i64),
}

#[derive(IntoPyObject)]
struct Result {
    status: String,
    code: i32,
}
// Converts to Python dict: {"status": "ok", "code": 200}
```

Note: `IntoPy` and `ToPyObject` are deprecated since PyO3 0.23. Use `IntoPyObject` instead.

## Error Handling

### PyResult and Built-in Exceptions

```rust
use pyo3::prelude::*;
use pyo3::exceptions::PyValueError;

#[pyfunction]
fn parse_int(s: &str) -> PyResult<i64> {
    s.parse::<i64>().map_err(|e| PyValueError::new_err(e.to_string()))
}
```

### Custom Exception Types

```rust
pyo3::create_exception!(my_module, ValidationError, pyo3::exceptions::PyException);

#[pyfunction]
fn validate(input: &str) -> PyResult<String> {
    if input.is_empty() {
        Err(ValidationError::new_err("input cannot be empty"))
    } else {
        Ok(input.to_uppercase())
    }
}
```

### Using thiserror

```rust
use thiserror::Error;

#[derive(Error, Debug)]
enum AppError {
    #[error("validation failed: {0}")]
    Validation(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

impl From<AppError> for PyErr {
    fn from(err: AppError) -> PyErr {
        match err {
            AppError::Validation(msg) => PyValueError::new_err(msg),
            AppError::Io(e) => PyIOError::new_err(e.to_string()),
        }
    }
}
```

## NumPy Integration

```toml
# Cargo.toml
[dependencies]
pyo3 = "0.28"
numpy = "0.28"    # rust-numpy, version-matched to pyo3
ndarray = "0.16"
```

### Zero-Copy Patterns

```rust
use numpy::{PyArrayDyn, PyReadonlyArrayDyn, PyArray1, IntoPyArray, PyArrayMethods};
use pyo3::prelude::*;

// Zero-copy read from Python
#[pyfunction]
fn sum_array<'py>(arr: PyReadonlyArrayDyn<'py, f64>) -> f64 {
    arr.as_array().sum()  // as_array() is zero-copy
}

// Zero-copy transfer to Python (ownership moves)
#[pyfunction]
fn make_array<'py>(py: Python<'py>, size: usize) -> Bound<'py, PyArray1<f64>> {
    ndarray::Array1::linspace(0.0, 1.0, size).into_pyarray(py)
}

// In-place mutation
#[pyfunction]
fn double_in_place<'py>(arr: &Bound<'py, PyArrayDyn<f64>>) -> PyResult<()> {
    let mut rw = arr.readwrite();
    rw.as_array_mut().mapv_inplace(|x| x * 2.0);
    Ok(())
}
```

| Pattern | Copies? | Direction |
|---------|---------|-----------|
| `PyReadonlyArray::as_array()` | No | Python -> Rust (read) |
| `PyReadwriteArray::as_array_mut()` | No | Python -> Rust (write) |
| `array.into_pyarray(py)` | No | Rust -> Python (ownership transfer) |
| `array.to_pyarray(py)` | Yes | Rust -> Python (copy) |

## Async Support

### Built-in Async (PyO3 0.28+, simplest)

```rust
#[pyfunction]
async fn fetch_data(url: String) -> PyResult<String> {
    let resp = reqwest::get(&url).await
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;
    resp.text().await
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))
}
```

### Static Tokio Runtime (for blocking API)

```rust
use std::sync::OnceLock;
use tokio::runtime::Runtime;

fn get_runtime() -> &'static Runtime {
    static RT: OnceLock<Runtime> = OnceLock::new();
    RT.get_or_init(|| Runtime::new().expect("Failed to create Tokio runtime"))
}

#[pyfunction]
fn blocking_fetch(py: Python<'_>, url: String) -> PyResult<String> {
    py.allow_threads(|| {
        get_runtime().block_on(async {
            reqwest::get(&url).await
                .map_err(|e| PyRuntimeError::new_err(e.to_string()))?
                .text().await
                .map_err(|e| PyRuntimeError::new_err(e.to_string()))
        })
    })
}
```

## GIL Management

### Release GIL for Computation

```rust
#[pyfunction]
fn heavy_compute(py: Python<'_>, data: Vec<f64>) -> f64 {
    py.allow_threads(|| {
        // Pure Rust — no Python API calls allowed here
        data.iter().map(|x| x.powi(2)).sum::<f64>().sqrt()
    })
}
```

### Optimal Pattern: Extract → Release → Compute → Return

```rust
#[pyfunction]
fn process(py: Python<'_>, input: PyReadonlyArrayDyn<'_, f64>) -> PyResult<f64> {
    let array = input.as_array().to_owned(); // copy while GIL held
    let result = py.allow_threads(|| {       // release GIL
        array.iter().map(|x| x.exp()).sum::<f64>()
    });
    Ok(result)                               // GIL re-acquired
}
```

### Safe Statics with PyOnceLock

```rust
use pyo3::sync::PyOnceLock;

static CACHED: PyOnceLock<Py<PyModule>> = PyOnceLock::new();

fn get_json(py: Python<'_>) -> &Py<PyModule> {
    CACHED.get_or_init(py, || py.import("json").unwrap().unbind())
}
```

Never use `lazy_static` or `std::sync::OnceLock` for values that interact with Python — use `PyOnceLock` to avoid GIL deadlocks.

### Signal Handling

```rust
#[pyfunction]
fn long_running(py: Python<'_>) -> PyResult<()> {
    for i in 0..1_000_000 {
        if i % 10_000 == 0 {
            py.check_signals()?;  // allow Ctrl+C
        }
    }
    Ok(())
}
```

## Common Pitfalls

### GIL Deadlocks
- **Rayon + GIL**: Always `py.allow_threads()` before entering rayon parallel iterators.
- **Mutex + GIL**: Release GIL before locking mutexes that other threads may hold.
- **`lazy_static` + Python**: Use `PyOnceLock` instead.

### Lifetime Issues
- `Bound<'py, T>` borrows from `Python<'py>` — cannot outlive the GIL scope.
- Use `Py<T>` for long-lived references; convert back with `.bind(py)`.
- `#[pyclass]` fields cannot contain `Bound<'py, T>` — use `Py<T>`.

### Memory
- Tight loops holding GIL cause memory growth. Periodically release and re-acquire.
- Circular references between `#[pyclass]` and Python objects may not be collected. Use weak references or implement `__traverse__` / `__clear__`.

### Other
- `#[pyclass]` requires `Send` by default. Use `#[pyclass(unsendable)]` if needed.
- `String` conversion is not zero-cost (UTF-8 → UCS-4). For hot paths, prefer `&[u8]` / `bytes`.
- Forgetting `crate-type = ["cdylib"]` produces an rlib that Python can't import.

## Performance Tips

```rust
// GOOD: borrow string (zero-copy from Python str)
#[pyfunction]
fn process(data: &str) -> String { ... }

// BAD: takes ownership, forces clone
#[pyfunction]
fn process(data: String) -> String { ... }

// GOOD: Cow for conditional ownership
use std::borrow::Cow;
#[pyfunction]
fn normalize(input: &str) -> Cow<'_, str> {
    if input.contains(' ') {
        Cow::Owned(input.replace(' ', "_"))
    } else {
        Cow::Borrowed(input)
    }
}
```

- Release GIL with `py.allow_threads()` for CPU-bound work.
- Get `Python` token via `.py()` on `Bound` values (zero-cost). Avoid `Python::attach` in hot paths.
- Batch Python API calls to minimize cross-language overhead.
- Use `py-spy` profiler to see both Python and Rust frames.

## Testing

### Two-Layer Strategy

**Layer 1: Rust tests (`cargo test`)**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pure_rust() {
        let p = Point { x: 3.0, y: 4.0, label: None };
        assert_eq!(p.distance(&Point { x: 0.0, y: 0.0, label: None }), 5.0);
    }
}
```

**Layer 2: Python tests (`pytest`)**

```python
import pytest
import my_project

def test_add():
    assert my_project.add(2, 3) == 5

def test_point():
    p = my_project.Point(1.0, 2.0)
    assert p.x == 1.0

def test_error():
    with pytest.raises(ValueError):
        my_project.validate("")
```

### Development Workflow

```bash
pip install maturin pytest
maturin develop           # build + install in dev mode
pytest tests/ -v          # run Python tests
cargo test                # run Rust tests
```

## Packaging: CI with maturin-action

Generate starter CI: `maturin generate-ci github > .github/workflows/ci.yml`

```yaml
name: Build wheels
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: x86_64
          - os: ubuntu-latest
            target: aarch64
          - os: macos-14
            target: aarch64
          - os: windows-latest
            target: x86_64
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - uses: PyO3/maturin-action@v1
        with:
          target: ${{ matrix.target }}
          args: --release --out dist
          manylinux: auto
      - uses: actions/upload-artifact@v4
        with:
          name: wheels-${{ matrix.os }}-${{ matrix.target }}
          path: dist

  publish:
    needs: build
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    permissions:
      id-token: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          pattern: wheels-*
          merge-multiple: true
          path: dist
      - uses: PyO3/maturin-action@v1
        with:
          command: upload
          args: --non-interactive --skip-existing dist/*
```

Cross-compilation shortcut: `maturin build --release --target aarch64-unknown-linux-gnu --zig`
