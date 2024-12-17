# RISC-V CIRCT Flow
This repository contains scripts that tie everything together to run testbenches for the Menace RISC-V core in Arcilator.

## Setup
1. **Install git submodules:**

```
$ git clone https://github.com/YAGRIT/flow
$ cd flow
$ git submodule update --init --recursive --progress
```

2. **Build MLIR:**

```
$ cd circt/llvm
$ mkdir build
$ cd build
$ cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS=mlir -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_BUILD_TYPE=DEBUG -DLLVM_USE_SPLIT_DWARF=ON
$ ninja
```

3. **Build CIRCT:**

```
$ cd circt
$ mkdir build
$ cd build
$ cmake -G Ninja .. -DMLIR_DIR=$PWD/../llvm/build/lib/cmake/mlir -DLLVM_DIR=$PWD/../llvm/build/lib/cmake/llvm -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_BUILD_TYPE=DEBUG -DLLVM_USE_SPLIT_DWARF=ON -DCIRCT_SLANG_FRONTEND_ENABLED=ON
$ ninja
```

4. **Run testbenches:**

```
$ make test
```
