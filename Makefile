#=======================================#
#																				#
#								Flow: 									#
#		circt-verilog => | .mlir | 					#
#			=>	circt-opt => | .mlir |				#
#				=>	arcilator => |  .ll  |			#
#					=>				llc => |  .s   |		#
#						=>				gcc => |  .o   | 	#
#																			  #
#=======================================#

include circt/make_build/Makefile 
include slang/make_build/Makefile

CIRCT_VRG ?= 	$(shell which circt-verilog)
CIRCT_OPT ?= 	$(shell which circt-opt)
ARCILATOR ?= 	$(shell which arcilator)
LLC   		?=	$(shell which llc-14)
LLC_FLAGS =		-opaque-pointers 
CC 				?=	$(shell which gcc)
RISC_V_DIR=		risc-v
OBJS			=		$(wildcard $(RISC_V_DIR)/core/*.sv)
BUILD_DIR	=		$(RISC_V_DIR)/build

#===-------------------------------------
# Default flow  
#===-------------------------------------

asm-to-bin: $(BUILD_DIR)/%.s 
	$(CC) -o $(basename $<).o $< 

# --filetype=obj <-- сразу в объекты 
ll-to-asm: $(BUILD_DIR)/%.ll 
	$(LLC) $(LLC_FLAGS) -o $(basename $<).s $< 

mlirs-to-ll: $(BUILD_DIR)/%_op.mlir
	$(ARCILATOR) -o $(basename $<).ll $< 

mlirs-opt: $(BUILD_DIR)/%.mlir 
	$(CIRCT_OPT) -o $(basename $<)_opt.mlir $< 

sv-to-mlirs: $(OBJS)
	$(CIRCT_VRG) $(OBJS)

#===-------------------------------------
# Test flow on single file
#===-------------------------------------

test-asm-to-bin: $(BUILD_DIR)/$(TEST_MOD).s 
	$(CC) -o $(TEST_MOD).o $^ 

test-ll-to-asm: $(BUILD_DIR)/$(TEST_MOD).ll 
	$(LLC) $(LLC_FLAGS) $< > $(BUILD_DIR)/$(TEST_MOD).s 
	@echo "#---------ASM----------#"
	cat $(BUILD_DIR)/$(TEST_MOD).s
	@echo "#-----------------------#"

test-mlirs-to-ll: $(BUILD_DIR)/$(TEST_MOD).mlir 
	$(ARCILATOR) $< > $(BUILD_DIR)/$(TEST_MOD).ll 
	@echo "#--------LLVM IR--------#"
	cat $(BUILD_DIR)/$(TEST_MOD).ll
	@echo "#-----------------------#"

test-mlirs-opt: $(BUILD_DIR)/$(TEST_MOD).mlir
	mv $(BUILD_DIR)/$(TEST_MOD).mlir $(BUILD_DIR)/$(TEST_MOD)_pre.mlir 
	$(CIRCT_OPT) $(BUILD_DIR)/$(TEST_MOD)_pre.mlir > $(BUILD_DIR)/$(TEST_MOD).mlir 
	@echo "#-----Optimized Mlir----#"
	cat $(BUILD_DIR)/$(TEST_MOD).mlir
	@echo "#-----------------------#"

test-sv-to-mlirs: $(RISC_V_DIR)/core/$(TEST_MOD).sv 
	@echo "#----SystemVerilog -----#"
	cat $(RISC_V_DIR)/core/$(TEST_MOD).sv 
	@echo "------------------------#"
	$(CIRCT_VRG) $< > $(BUILD_DIR)/$(TEST_MOD).mlir
	@echo "#---------MLIR---------#"
	cat $(BUILD_DIR)/$(TEST_MOD).mlir
	@echo "#-----------------------#"

#===-------------------------------------
# Convenience 
#===-------------------------------------

all: sv-to-mlirs mlirs-opt mlirs-to-ll ll-to-asm asm-to-bin

single: test-sv-to-mlirs test-mlirs-opt test-mlirs-to-ll test-ll-to-asm test-asm-to-bin

.PHONY: all 
