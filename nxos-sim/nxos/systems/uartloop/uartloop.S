/** @file uartloop.S
 *  @brief UART Loopback Program
 *
 * Test UART loopback
 * Echo what is sent to the UART to the output
 * The input is also displayed on the LCD text terminal
 *
 * This file must be processed using cpp before assembly.
 */

/* Copyright (C) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#define __ASSEMBLY__
#include "base/interwork.h"
#include "base/debug_stub.h"
#include "base/lib/scaffolding/scaffolding.h"

/* Reference C functions which do not have ASM headers */
	.extern nx_uart_read_avail
	.extern nx_uart_write_avail
	.extern	nx_uart_getchar
	.extern nx_uart_putchar
	.extern nx_uart_readbuf
	.extern nx_uart_writebuf
	.equ	UART_RXBUFSIZE, 64

#define ASCII_ESC	0x1B			//  ASCII - ESC
#define ASCII_ENTER  0xA			//  ASCII - ENTER

#define USE_BUFFEREDIO				/* Use buffered reads/writes instead of character read/write */

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
//#define ENABLE_BREAKPOINTS
#undef ENABLE_BREAKPOINTS

	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1200
	.equ	SYSTICK_500MS, 500
	.equ	LOOPCNT, 3

	//Set Min-Max Decimal Range for ASCII value for numbers
	.equ 	NUM_MIN, 48
	.equ 	NUM_MAX, 57

	//Set Min-Max Decimal Range for Uppercase
	.equ 	UPPER_MIN, 65
	.equ 	UPPER_MAX, 90

	//Set Min-Max Decimal Range for lowercase
	.equ 	LOWER_MIN, 97
	.equ	LOWER_MAX, 122
	.equ 	NUM_VALID_INPUT_CHARS, 70

	//FROM WTC LECTURE
	.equ LEFT_SIDE_SEGMENT, 0xFF200020
	.equ RIGHT_SIDE_SEGMENT, 0xFF200030
	.equ NUM_7SEG, 8
	.equ INPUT_BUFSIZE, 16
	.equ SEG_1_BUFOFFSET, 0x03
	.equ SEG_2_BUFOFFSET, 0x07

.data
.align 4

.align 2

#ifdef USE_BUFFEREDIO

buflen:  .word 0
charbuf: .space UART_RXBUFSIZE, 0
input_buffer: .space 16
output_buffer:	.space	8

#endif

title:	 .asciz "Scrolling Banner\n"
prompt:	 .asciz "Type into the UART panel\n" //\nESC to exit\n
bye:	 .asciz "\nGoodbye!\n"
uartchr: .asciz "_"				// dummy string for output

// ASCII LUT
/*
	0x20 -> Space
	0x30 - 0x39 -> 0 - 9
	0x41 - 0x5A -> A - Z
	0x61 - 0x7A -> a - z
	0x3F -> ?
	0x7C -> |
	0x5F -> _
	0x5B -> [
	0x5D -> ]
	0x2D -> -

*/
ascii_table: .byte 		0x20, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x3F, 0x7C, 0x5F, 0x5B, 0x5D, 0x2D
segments_char: .byte    0x00, 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x3D, 0x74, 0x30, 0x1E, 0x76, 0x38, 0x55, 0x37, 0x3F, 0x73, 0x6F, 0x50, 0x6D, 0x78, 0x3E, 0x2A, 0x6A, 0x49, 0x6E, 0x5B, 0x5F, 0x7C, 0x58, 0x5E, 0x7B, 0x71, 0x67, 0x74, 0x10, 0x1F, 0x70, 0x30, 0x55, 0x54, 0x5C, 0x73, 0x6F, 0x50, 0x6D, 0x78, 0x1C, 0x2A, 0x6A, 0x49, 0x66, 0x52, 0x53, 0x30, 0x08, 0x39, 0x0F, 0x40


.code 32
.text
.align 	4
// WARNING: Don't put any routines here between the .text and the main: label.
// CPUlator will point the starting PC to the beginning of the .text section and start executing from there.

/** main
 *    Main Program
 */
	.global	main
main:
/* Needed to support CPUlator system init
 * since it starts execution from main() and does not go through the system reset handler
 */
#include "cpulator_stub.inc"

	push	{r4-r12,lr}			// Preserve all AAPCS registers to avoid CPUlator warnings.
	bl		nx_proginit
	ldr		r4, =title
	mov		r0, r4
	mov		r1, #17
	bl		nx_uart_writebuf

#ifdef __CPULATOR__
	// Allow CPUlator to execute ISR before hitting the breakpoint
	mov		r0, #SYSTICK_500MS
	bl		nx_systick_wait_ms
#endif

#ifdef ENABLE_BREAKPOINTS
	dbg__bkpt_arm
#else
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms
#endif

break:
	nop		/* Provide GDB with a safe instruction to breakpoint at */

/********************* Begin Customization Here *********************/

	ldr		r4, =prompt
	mov		r0, r4
	mov		r1, #26
	bl		nx_uart_writebuf

	mov		r0, #SYSTICK_500MS		/* Wait 500 ms */
	bl		nx_systick_wait_ms

	mov		r1,  #0					/* offset for accessing input buffer */
	ldr		r5,  =output_buffer
	ldr		r6,  =segments_char
	ldr		r10, =ascii_table
	ldr 	r11, =input_buffer

	mov 	r9,  #SEG_2_BUFOFFSET
	mov 	r12, #8

//	R0 	-	User Input		R1	-	S			R2	-	S
//	R3 	-	S				R4	-	S			R5	-	S
//	R6 	-	S				R7	-	S			R8	-	S
//	R9 	-	S				R10	-	S			R11	-	LEFT_SEGMENT
//	R12	-	RIGHT_SEGMENT

loop:
	bl		nx_uart_getchar			/* get input from UART */
	mov		r4, #NUM_VALID_INPUT_CHARS
	mov     r7, r0                  /* keep for UART display */

input_func:
	sub 	r4, r4, #1
	ldrb 	r8, [r10, r4]			// Load ASCII table to r8
	cmp 	r0, r8
	bleq 	IB_Storage

	cmp 	r4, #0
	bne 	input_func

display:
	cmp		r7, #ASCII_ENTER		// Enter?
	ittt	eq						// If true , then execute the next 3 steps
	moveq	r1, #0 					// Set R1=0  if true
	moveq	r4, #0 					// Set R4=0 if true
	bleq	OB_Storage
	cmp		r7, #ASCII_ESC			// Exit?
	bne		loop
	b	 	exit_loop

OB_Storage:
	ldrb 	r8, [r11, r1]
	strb	r8, [r5, r9]
	sub 	r9, r9, #1
	add		r1, r1, #1				@ point to next input buffer location
	cmp		r1, r12
	bne		OB_Storage

segment_display:
	ldr    	r1, =LEFT_SIDE_SEGMENT
	ldr		r0, [r5]
	str		r0, [r1]
	ldr 	r3, =RIGHT_SIDE_SEGMENT
	ldr		r0, [r5, #4]
	str		r0, [r3]

	ldrb 	r8, [r11, r12]
	cmp 	r8, #0

	//Initilaze R4 as count down counter
	moveq 	r4, #3
	beq		flicker

segment_processing:
	add 	r4, r4, #1
	mov 	r1, r4
	add 	r12, r12, #1
	mov 	r9, #SEG_2_BUFOFFSET 	//reset

	mov		r0, #SYSTICK_500MS
	bl		nx_systick_wait_ms

	bl		OB_Storage

flicker:
	// Turn display off
	mov		r0, #SYSTICK_500MS
	bl		nx_systick_wait_ms

	mov		r2, #0
	ldr    	r1, =LEFT_SIDE_SEGMENT
	str		r2, [r1]
	ldr    	r3, =RIGHT_SIDE_SEGMENT
	str		r2, [r3]

	mov		r0, #SYSTICK_500MS
	bl		nx_systick_wait_ms

	// Turn display on
	ldr    	r1, =LEFT_SIDE_SEGMENT
	ldr		r0, [r5]
	str		r0, [r1]
	ldr 	r3, =RIGHT_SIDE_SEGMENT
	ldr		r0, [r5, #4]
	str		r0, [r3]

	//Reduce countdown counter by 1
	sub		r4, r4, #1

	// Check if Counter is 0, if not flicker once again
	cmp		r4, #0
	bne		flicker

	// RESET INPUT BUFFER TO 16 BITS
	mov		r4, #16
	mov		r0, #ASCII_ENTER
	bl		nx_uart_putchar
	mov		r0, #0

new_loop:
	//Reduce bit by 1
	sub		r4, r4, #1
	strb	r0, [r11, r4]
	//Check if buffer is 0 , if not loop back and store
	cmp		r4, #0
	bne		new_loop

	//Reinitialize from starting point
	mov		r9, #7
	mov		r12, #8
	mov		r1, #0

	// Return
	b		loop

IB_Storage:
	ldrb 	r8, [r6,r4]
	strb	r8, [r11, r1]
	add		r1, r1, #1			@ point to next input buffer location
	bl	    nx_uart_putchar
	b		display

exit_loop:
	ldr		r0, =bye
	mov		r1, #11
	bl		nx_uart_writebuf

/********************** End Customization Here **********************/
exit_main:
	bl		nx_progshutdown
	pop		{r4-r12,pc}			// Restore all AAPCS registers to avoid CPUlator warnings.


.end
