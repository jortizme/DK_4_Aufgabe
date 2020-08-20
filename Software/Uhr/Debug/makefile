################################################################################
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.init

RM := rm -rf

# All of the sources participating in the build are defined here
-include sources.mk
-include src/subdir.mk
-include subdir.mk
-include objects.mk

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
endif

-include ../makefile.defs

# Add inputs and outputs from these tool invocations to the build variables 

# All Target
all: Uhr.elf

# Tool invocations
Uhr.elf: $(OBJS) $(USER_OBJS)
	@echo 'Building target: $@'
	@echo 'Invoking: Cross GCC Linker'
	mips-sde-elf-gcc -nostartfiles -nodefaultlibs -nostdlib -static -Xlinker -TC:/DK_Praktikum/Software/Uhr/lscript.ld -EL -o "Uhr.elf" $(OBJS) $(USER_OBJS) $(LIBS)
	@echo 'Finished building target: $@'
	@echo ' '
	$(MAKE) --no-print-directory post-build

# Other Targets
clean:
	-$(RM) $(EXECUTABLES)$(OBJS)$(C_DEPS) Uhr.elf
	-@echo ' '

post-build:
	-mips-sde-elf-objdump.exe -h -j.text -j.data -j.bss Uhr.elf & mips-sde-elf-objdump.exe -h -t -j.text -j.data -j.bss -S Uhr.elf > Uhr_diss.txt & mips-sde-elf-objcopy.exe -O ihex Uhr.elf Uhr.hex
	-@echo ' '

.PHONY: all clean dependents post-build

-include ../makefile.targets
