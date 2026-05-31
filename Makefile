s? = $(subst $(empty) ,?,$1)
?s = $(subst ?, ,$1)
dirx = $(call ?s,$(dir $(call s?,$1)))
export HERE = $(patsubst %/,%,$(call dirx,$(abspath $(lastword $(MAKEFILE_LIST)))))

RVTOOLPREFIX=/opt/riscv/bin/riscv64-unknown-linux-gnu-
RVGCC=$(RVTOOLPREFIX)gcc 
RVOBJCOPY=$(RVTOOLPREFIX)objcopy 

TSCALE  := 1ns/1ns
OUT_DIR := out
OUT_MT  ?= 12
SIM_MT  ?= 4

GCC_FLAGS=-march=rv32i -mabi=ilp32 -static -nostdlib -nostartfiles -mcmodel=medany -g
VERILATOR_FLAGS=-j $(OUT_MT) --threads $(SIM_MT) --timescale $(TSCALE) --top-module tb --cc --exe --build --assert --x-initial-edge --timing --trace --trace-underscore -Wno-WIDTH -Wno-UNSIGNED -Wno-UNOPTTHREADS -O2 -LDFLAGS -lcppdap -LDFLAGS -ldw -LDFLAGS -lelf -CFLAGS -std=c++20

ASSEMBLY_SOURCES=$(notdir $(wildcard *.s))
ASSEMBLY_SOURCES+=$(addprefix "$(HERE)/src/, $(addsuffix ",$(notdir $(wildcard src/*.s))))

VERILOG_SOURCES:=$(addprefix "$(HERE)/, $(addsuffix ",$(notdir $(wildcard *.v *.sv *.c *.cpp))))
VERILOG_SOURCES+=$(addprefix "$(HERE)/src/, $(addsuffix ",$(notdir $(wildcard src/*.v src/*.sv src/*.c src/*.cpp))))

.PHONY: clean build_%

clean:
	rm -rf $(OUT_DIR)

$(OUT_DIR):
	mkdir -p $@

assembly_%: $(OUT_DIR)
ifeq ($(strip $(ASSEMBLY_SOURCES)),)
	@echo "No assembly sources found"
else
	$(RVGCC) $(GCC_FLAGS) -o $(OUT_DIR)/$(basename $*) -T mmio.ld $(ASSEMBLY_SOURCES)
	$(RVOBJCOPY) -O binary  $(OUT_DIR)/$*  $(OUT_DIR)/$*.bin
endif

verilog_%: $(OUT_DIR)
ifeq ($(strip $(VERILOG_SOURCES)),)
	@echo "No verilog sources found"
else
	cd $(OUT_DIR) && verilator $(VERILATOR_FLAGS) $(VERILOG_SOURCES)
	rm -f Vtb
	ln $(OUT_DIR)/obj_dir/Vtb Vtb
endif

build_%: $(OUT_DIR) assembly_% verilog_%
	@echo "Done"