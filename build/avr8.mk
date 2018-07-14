#
# avr8.mk - A simple makefile for AVR8 microcontroller
# Copyright (C) 2018 Marius Greuel. All rights reserved.
#

ifndef MCU
    $(error error : variable MCU is not defined)
endif

ifndef F_CPU
    $(error error : variable F_CPU is not defined)
endif

ifndef SOURCES
    $(error error : variable SOURCES is not defined)
endif

# Default tools from the AVR 8-bit toolchain
CC = avr-gcc
CXX = avr-g++
AS = avr-as
AR = avr-ar
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size
NM = avr-nm

# C/C++ compiler flags
C_AND_CXX_FLAGS += -mmcu=$(MCU)
C_AND_CXX_FLAGS += -MMD -MP
C_AND_CXX_FLAGS += $(OPTIMIZATION_FLAGS)
C_AND_CXX_FLAGS += -Wall
C_AND_CXX_FLAGS += -fpack-struct -fshort-enums
C_AND_CXX_FLAGS += -g

# C compiler flags
CFLAGS += -std=c99
CFLAGS += $(C_AND_CXX_FLAGS)
CFLAGS += -Wstrict-prototypes

# C++ compiler flags
CXXFLAGS += -std=c++11
CXXFLAGS += $(C_AND_CXX_FLAGS)
CXXFLAGS += -fno-exceptions

# Preprocessor flags
CPPFLAGS += -DF_CPU=$(F_CPU)

# Assembler flags
ASFLAGS += $(C_AND_CXX_FLAGS)
ASFLAGS += -x assembler-with-cpp

# Linker flags
LDFLAGS += $(C_AND_CXX_FLAGS)
LDFLAGS += -Wl,-Map=$(MAPFILE) -Wl,--relax -Wl,--gc-sections
LDLIBS += -lm

# Make flags
MAKEFLAGS += -r

# Size flags
SIZEFLAGS += --mcu=$(MCU)

FLASH_TOOL ?= avrdude
AVRDUDE_FLAGS ?= -c usbtiny
AVRDUDE_FLAGS += -p $(MCU)
MICRONUCLEUS_FLAGS += --run

ifdef DEBUG
    OPTIMIZATION_FLAGS ?= -Og
else
    CPPFLAGS += -DNDEBUG
    OPTIMIZATION_FLAGS ?= -Os
endif

OBJDIR ?= objs
TARGET ?= main
ELFFILE ?= $(OBJDIR)/$(TARGET).elf
BINFILE ?= $(OBJDIR)/$(TARGET).bin
HEXFILE ?= $(OBJDIR)/$(TARGET).hex
MAPFILE ?= $(OBJDIR)/$(TARGET).map
LSTFILE ?= $(OBJDIR)/$(TARGET).lst

VPATH += $(dir $(SOURCES))
OBJECTS += $(addprefix $(OBJDIR)/,$(addsuffix .o, $(basename $(notdir $(SOURCES)))))
DEPENDENCIES += $(OBJECTS:.o=.d)

# Select the command-line tools used in this makefile.
# The enviroment variable 'ComSpec' implies cmd.exe on Windows
ifdef ComSpec
    RM = del
    MKDIR = mkdir
    RMDIR = rmdir /s /q
    ospath = $(subst /,\,$1)
else
    RM = rm -f
    MKDIR = mkdir -p
    RMDIR = rm -r -f
    ospath = $1
endif

all: $(HEXFILE) size
	@echo Done: $(call ospath,$(abspath $(HEXFILE)))

$(ELFFILE): $(OBJECTS)
	$(CC) $(LDFLAGS) $^ -o $@ $(LDLIBS)

$(BINFILE): $(ELFFILE)
	$(OBJCOPY) -j .text -j .data -O binary $< $@

$(HEXFILE): $(ELFFILE)
	$(OBJCOPY) -j .text -j .data -O ihex $< $@

$(LSTFILE): $(ELFFILE)
	$(OBJDUMP) -h -S $< >$@

elf: $(ELFFILE)
bin: $(BINFILE)
hex: $(HEXFILE)
list: $(LSTFILE)

size: $(ELFFILE)
	@echo Project size:
	$(SIZE) $(SIZEFLAGS) $(ELFFILE)

flash: $(HEXFILE) size
ifeq ($(FLASH_TOOL),avrdude)
	$(FLASH_TOOL) $(AVRDUDE_FLAGS) -U flash:w:$(HEXFILE):i
else ifeq ($(FLASH_TOOL),micronucleus)
	$(FLASH_TOOL) $(MICRONUCLEUS_FLAGS) $(HEXFILE)
else
	@echo Error: FLASH_TOOL is invalid or not supported
endif

fuse:
ifeq ($(FLASH_TOOL),avrdude)
	echo $(AVRDUDE) $(AVRDUDE_FLAGS) -U lfuse:w:$(FUSE_L):m -U hfuse:w:$(FUSE_H):m -U efuse:w:$(FUSE_E):m
else
	$(warning warning : FLASH_TOOL is invalid or feature is not supported)
endif

clean:
	@echo Cleaning project...
	-$(RM) $(call ospath,$(ELFFILE)) $(call ospath,$(HEXFILE)) $(call ospath,$(LSTFILE)) 2>nul
	-$(RMDIR) $(call ospath,$(OBJDIR)) 2>nul

.PHONY: elf hex list size flash fuse clean

$(OBJECTS): | $(OBJDIR)

$(OBJDIR):
	$(MKDIR) $(call ospath,$(OBJDIR))

$(OBJDIR)/%.o: %.c
	@echo $(call ospath,$<)
	$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<

$(OBJDIR)/%.o: %.cpp
	@echo $(call ospath,$<)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c -o $@ $<

$(OBJDIR)/%.o: %.S
	@echo $(call ospath,$<)
	$(CC) $(ASFLAGS) $(CPPFLAGS) -c -o $@ $<

.SUFFIXES:

-include $(DEPENDENCIES)
