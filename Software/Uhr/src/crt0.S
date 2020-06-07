.set noreorder

.globl _mfc0
.globl _mtc0
.globl _ei
.globl _di

.equ SAVED_REGS, 18

.section .boottext

_RESET_Vector:
	b _RESET_Handler
	nop
	nop
	nop

_IP0_Vector:
	b _IP0_Handler
	nop
	nop
	nop

_IP2_Vector:
	b _IP2_Handler
	nop
	nop
	nop

_IP3_Vector:
	b _IP3_Handler
	nop
	nop
	nop

_IP4_Vector:
	b _IP4_Handler
	nop
	nop
	nop

_RESET_Handler:
	la 		$sp, _sp /* initialize the stack pointer */
	la 		$fp, _fp /* initialize the frame pointer */
	la 		$gp, _gp /* initialize the global pointer */
	ei               /* enable interrupts */
	j		_premain

_IP0_Handler:
	addiu 	$sp, $sp, - (SAVED_REGS * 4)
	sw    	$ra,  0($sp)
	jal   	_save_regs
	jal 	IP0_Handler
	jal   	_restore_regs
	lw    	$ra,  0($sp)
	addiu 	$sp, $sp, (SAVED_REGS * 4)
	eret

_IP2_Handler:
	addiu 	$sp, $sp, - (SAVED_REGS * 4)
	sw    	$ra,  0($sp)
	jal   	_save_regs
	jal 	IP2_Handler
	jal   	_restore_regs
	lw    	$ra,  0($sp)
	addiu 	$sp, $sp, (SAVED_REGS * 4)
	eret

_IP3_Handler:
	addiu 	$sp, $sp, - (SAVED_REGS * 4)
	sw    	$ra,  0($sp)
	jal   	_save_regs
	jal 	IP3_Handler
	jal   	_restore_regs
	lw    	$ra,  0($sp)
	addiu 	$sp, $sp, (SAVED_REGS * 4)
	eret

_IP4_Handler:
	addiu 	$sp, $sp, - (SAVED_REGS * 4)
	sw    	$ra,  0($sp)
	jal   	_save_regs
	jal 	IP4_Handler
	jal   	_restore_regs
	lw    	$ra,  0($sp)
	addiu 	$sp, $sp, (SAVED_REGS * 4)
	eret

_save_regs:
	.set noat
	sw $at,  4($sp)
	.set at
	sw $v0,  8($sp)
	sw $v1, 12($sp)
	sw $a0, 16($sp)
	sw $a1, 20($sp)
	sw $a2, 24($sp)
	sw $a3, 28($sp)
	sw $t0, 32($sp)
	sw $t1, 36($sp)
	sw $t2, 40($sp)
	sw $t3, 44($sp)
	sw $t4, 48($sp)
	sw $t5, 52($sp)
	sw $t6, 56($sp)
	sw $t7, 60($sp)
	sw $t8, 64($sp)
	sw $t9, 68($sp)
	jr $ra

_restore_regs:
	.set noat
	lw $at,  4($sp)
	.set at
	lw $v0,  8($sp)
	lw $v1, 12($sp)
	lw $a0, 16($sp)
	lw $a1, 20($sp)
	lw $a2, 24($sp)
	lw $a3, 28($sp)
	lw $t0, 32($sp)
	lw $t1, 36($sp)
	lw $t2, 40($sp)
	lw $t3, 44($sp)
	lw $t4, 48($sp)
	lw $t5, 52($sp)
	lw $t6, 56($sp)
	lw $t7, 60($sp)
	lw $t8, 64($sp)
	lw $t9, 68($sp)
	jr $ra

_ei:
	ei $v0
	jr $ra

_di:
	di $v0
	jr $ra
