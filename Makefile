CIRCT_VERILOG_FLAGS ?=
CIRCT_OPT_FLAGS ?=
ARCILATOR_FLAGS ?=

BUILD_DIR = build
MENACE_DIR = risc-v
TESTBENCH_DIR := $(MENACE_DIR)/testbenches
CIRCT_DIR = circt

CIRCT_BUILD_DIR = $(CIRCT_DIR)/build
CIRCT_BIN_DIR = $(CIRCT_BUILD_DIR)/bin

CIRCT_VERILOG ?= $(CIRCT_BIN_DIR)/circt-verilog
CIRCT_OPT ?= $(CIRCT_BIN_DIR)/circt-opt
ARCILATOR ?= $(CIRCT_BIN_DIR)/arcilator

CIRCT_OPT_PASSES ?= \
	--llhd-early-code-motion \
	--llhd-temporal-code-motion \
	--llhd-process-lowering \
	--llhd-desequentialize \
	--llhd-sig2reg \
	--canonicalize

EXPECTED_FAIL_FILES = \
	$(MENACE_DIR)/core/mmu.sv \
	$(MENACE_DIR)/core/rom.sv \

ALL_SV_FILES = $(shell find $(MENACE_DIR) -name '*.sv')
CORE_FILES = $(wildcard $(MENACE_DIR)/core/*.sv)
NON_FAILING_FILES = $(filter-out $(EXPECTED_FAIL_FILES),$(CORE_FILES))

SEARCH_PATHS = $(MENACE_DIR)/core $(MENACE_DIR)/sim

TESTBENCHES ?= $(patsubst $(TESTBENCH_DIR)/%.mlir,%,$(wildcard $(TESTBENCH_DIR)/*.mlir))

.PHONY: all-mlir test

# this prevents Make from removing intermediate files
# (such as %-hw.mlir when building %.mlir)
.NOTINTERMEDIATE:

all-mlir: $(NON_FAILING_FILES:$(MENACE_DIR)/%.sv=$(BUILD_DIR)/%.mlir)

$(BUILD_DIR)/%-moore.mlir: $(MENACE_DIR)/%.sv $(BUILD_DIR)/%.dep $(CIRCT_VERILOG)
	$(CIRCT_VERILOG) $(SEARCH_PATHS:%=-y %) $(CIRCT_VERILOG_FLAGS) --ir-moore -o $@ $<

$(BUILD_DIR)/%-hw.mlir: $(BUILD_DIR)/%-moore.mlir $(CIRCT_VERILOG)
	$(CIRCT_VERILOG) $(CIRCT_VERILOG_FLAGS) --format mlir --ir-hw -o $@ $<

$(BUILD_DIR)/%.mlir: $(BUILD_DIR)/%-hw.mlir $(CIRCT_OPT)
	$(CIRCT_OPT) $(CIRCT_OPT_FLAGS) $(CIRCT_OPT_PASSES) -o $@ $<

$(BUILD_DIR)/test/%.mlir: $(TESTBENCH_DIR)/%.mlir
	@mkdir -p $(dir $@)
	awk -f scripts/remove-outer-module.awk $^ > $@

$(BUILD_DIR)/test/%.mlir-run: $(BUILD_DIR)/test/%.mlir $(ARCILATOR) build/.FORCE
	$(ARCILATOR) $(ARCILATOR_FLAGS) --run $< | FileCheck $<

test: $(foreach file,$(TESTBENCHES),$(BUILD_DIR)/test/$(file).mlir-run)

%/:
	mkdir -p $@

build/.FORCE:

$(CIRCT_VERILOG) $(CIRCT_OPT) $(ARCILATOR):
	$(error Could not find `$@`. Make sure to build CIRCT before running make)

# testbench dependencies
$(BUILD_DIR)/core/alu-patched.mlir: patches/alu.mlir.patch $(BUILD_DIR)/core/alu.mlir
	patch -p1 -o $@ < $<

$(BUILD_DIR)/test/alu.mlir: $(BUILD_DIR)/core/alu-patched.mlir

# SV module dependency tracking
DEP_core__alu = core/enums.sv
DEP_core__counter = core/register.sv
DEP_core__cpu = core/datapath.sv core/cu.sv
DEP_core__cu = core/enums.sv core/mux.sv
DEP_core__datapath = core/counter.sv core/le_to_be.sv core/regfile.sv core/register.sv core/enums.sv core/alu.sv core/csr.sv core/adder.sv core/mux.sv
DEP_core__led_mmap = core/register.sv

# (function) converts, e.g., core/cu to core__cu
DEP_VAR_NAME = DEP_$(subst /,__,$(1))
# (function) converts, e.g., core/cu.sv to $(BUILD_DIR)/core/cu.dep
DEP_PATH = $(patsubst %.sv,$(BUILD_DIR)/%.dep,$(1))

define DEP_TEMPLATE
$$(BUILD_DIR)/$(1).dep: $$(MENACE_DIR)/$(1).sv $(call DEP_PATH,$(value $(call DEP_VAR_NAME,$(1)))) | $(dir $(BUILD_DIR)/$(1).dep)
	@touch $$@

endef

$(foreach file,$(ALL_SV_FILES),$(eval $(call DEP_TEMPLATE,$(patsubst $(MENACE_DIR)/%.sv,%,$(file)))))
