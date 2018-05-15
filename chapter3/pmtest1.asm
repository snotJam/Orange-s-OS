;================================
;初识保护模式
;编译方法 nasm pmtest1.asm -o pmtest1.bin
;
;==================================
%include "pm.inc"		;常量，宏，以及一些说明

org 07c00h
	jmp LABLE_BEGIN
	
[SECTION .gdt]
;GDT
;									段地址		段界限		  属性
LABLE_GDT:			Descriptor			0,			0,			0		;空描述符
LABLE_DESC_CODE32:	Descriptor			0,	SegCode32Len=1,		DA_C+DA_32	;非一致代码段
LABLE_DESC_VIDEO:	Descriptor		0B8000h,		0ffffh,		DA_DRW		;显存首地址
;GDT结束

GdtLen	equ	$-LABLE_GDT		;GDT长度
GdtPtr	dw	GdtLen-1		;GDT界限
		dd	0				;GDT基地址

;GDT选择子
SelectorCode32	equ	LABLE_DESC_CODE32	-LABLE_GDT
SelectorVideo	equ	LABLE_DESC_VIDEO	-LABLE_GDT
;end of [SECTION .gdt]

[SECTION .s16]
[BITS 16]
LABLE_BEGIN:
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov sp,0100h
	
	;初始化32位代码段描述
	xor eax,eax
	mov ax,cs
	shl eax,4
	add eax,LABLE_DESC_CODE32
	mov word [LABLE_DESC_CODE32+2],ax
	mov eax,16
	mov byte [LABLE_DESC_CODE32+4],al
	mov byte [LABLE_DESC_CODE32+7],ah
	
	;为加载GDTR作准备
	xor eax,eax
	mov ax,ds
	shl eax,4
	add eax,LABLE_GDT		;eax<-gdt基地址
	mov dword [GdtPtr+2],eax	;GdtPtr+2<-gdt基地址
	
	;加载GDTR
	lgdt [GdtPtr]
	
	;关闭中断
	cli
	
	;打开地址线A20
	in al,92h
	or al,00000010b
	out 92h,al
	
	;准备切换到保护模式
	mov eax,cr0
	or eax,l
	mov cr0,eax
	
	;真正进入保护模式
	jmp dword SelectorCode32:0		;执行这一句会把SelectorCode32装入cs，并跳转到SelectorCode32:0处
	
;End of [SECTION .s16]

[SECTION .s32]		;32位代码段，由实模式跳入
[BITS 32]
LABLE_SEG_CODE32:
	mov ax,SelectorVideo
	mov gs,ax		;视频段选择子
	
	mov edi,(80*11+79)*2		;屏幕第11行，第79列
	mov ah,0Ch					;0000：黑底，1100：红字
	mov al,'p'					
	mov [gs:edi],ax
	
	;到此停止
	jmp $
	
SegCode32Len equ $-LABLE_SEG_CODE32
;END of [SECTION .s32]