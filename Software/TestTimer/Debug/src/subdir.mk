################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/cpu.c \
../src/io.c \
../src/main.c \
../src/memcpy.c \
../src/memset.c \
../src/premain.c 

S_UPPER_SRCS += \
../src/crt0.S 

OBJS += \
./src/cpu.o \
./src/crt0.o \
./src/io.o \
./src/main.o \
./src/memcpy.o \
./src/memset.o \
./src/premain.o 

C_DEPS += \
./src/cpu.d \
./src/io.d \
./src/main.d \
./src/memcpy.d \
./src/memset.d \
./src/premain.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: Cross GCC Compiler'
	mips-sde-elf-gcc -I"C:\DK_Praktikum\Software\TestTimer\inc" -O0 -g3 -Wall -c -fmessage-length=0 -mips1 -EL -fno-delayed-branch -mno-check-zero-division -ggdb -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/%.o: ../src/%.S
	@echo 'Building file: $<'
	@echo 'Invoking: Cross GCC Assembler'
	mips-sde-elf-as -mips32r2 -EL -g -gstabs+ -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


