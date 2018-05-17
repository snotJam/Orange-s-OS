;-----------------------------------------------------
;因为书中有省略，所以这里的GDT是在pmtest2的基础上增加的
;可能加的位置不正确，以后再回头改
;
;---------------------------------------------------
%include "pm.inc"		;常量，宏，以及一些说明

org 07c00h
	jmp LABLE_BEGIN
	
[SECTION .gdt]
;GDT
;									段地址		段界限		  属性
LABLE_GDT:			Descriptor			0,			0,			0		;空描述符
LABLE_NORMAL:		Descriptor			0,		0ffffh,			DA_DRW		;Normal描述符
LABLE_DESC_CODE32:	Descriptor			0,	SegCode32Len-1,		DA_C+DA_32	;非一致代码段 32
LABLE_DESC_CODE16:	Descriptor			0,		0ffffh,			DA_C		;非一致代码段 16
LABLE_DESC_DATA:	Descriptor			0,		DataLen-1,		DA_DRW		;Data
LABLE_DESC_STACK:	Descriptor			0,		TopOfStack,		DA_DRWA+DA_32	;stack 32位
LABLE_DESC_TEST:	Descriptor		05000000h,	0ffffh,			DA_DRW
LABLE_DESC_VIDEO:	Descriptor	  	0B8000h,	0ffffh,			DA_DRW		;显存首地址
;添加的部分
LABLE_DESC_LDT:		Descriptor			0,		LDTLen-1,		DA_LDT		;LDT

;GDT结束

GdtLen	equ	$-LABLE_GDT		;GDT长度
GdtPtr	dw	GdtLen-1		;GDT界限
		dd	0				;GDT基地址

;GDT选择子
SelectorNormal	equ	LABLE_DESC_CODE32	-LABLE_GDT
SelectorCode32	equ	LABLE_DESC_CODE32	-LABLE_GDT
SelectorCode16	equ	LABLE_DESC_CODE16	-LABLE_GDT
SelectorData	equ	LABLE_DESC_DATA		-LABLE_GDT
SelectorStack	equ	LABLE_DESC_STACK	-LABLE_GDT
SelectorTest	equ	LABLE_DESC_TEST		-LABLE_GDT
SelectorVideo	equ	LABLE_DESC_VIDEO	-LABLE_GDT
;LDT
SelectorLDT		equ	LABLE_DESC_LDT		-LABLE_GDT
;end of [SECTION .gdt]

[SECTION .data1]	;数据段
	ALIGN	32
	[BITS 32]
	LABLE_DATA:
		SPValueInRealMode	dw	0
		;字符串
		PMMessage:			db "In Project Mode now ^-^", 0		;在保护模式中显示
		OffsetPMMessage		equ	PMMessage-$$
		StrTest:			db	"ABCDEFGHIJKLMN",0
		OffsetStrTest		equ	StrTest-$$
		DataLen				equ	$-LABLE_DATA
;END of [SECTION .data1]

;全局堆栈段
[SECTION .gs]		
	ALIGN	32
	[BITS 32]
	LABLE_STACK:
		times 512 db 0
	TopOfStack		equ 	$-LABLE_STACK-1
;END of [SECTION .gs]

mov ax,cs
mov ds,ax
mov es,ax
mov ss,ax
mov sp,0100h
mov [LABLE_GO_BACK_TO_REAL+3],ax		;LABLE_GO_BACK_TO_REAL+3刚好是Segment的地址
										;此处先将cs值给了ax，最后又将ax中的值给了Segment，也就是此时segment地址为cs值
										;那么代码jmp 0,LABLE_REAL_ENTRY就变成了jmp cs_real_mode:LABLE_REAL_ENTRY
										;将跳到标号LABLE_REAL_ENTRY处
										

;初始化段描述符
xor	eax,eax
mov ax,ds
mov eax,4
add eax,LABLE_DATA
mov word [LABLE_DESC_DATA+2],ax
shr eax,16
mov byte [LABLE_DESC_DATA+4],al
mov byte [LABLE_DESC_DATA+7],ah

;在跳回实模式后，将重置各寄存器的值，恢复sp（堆栈寄存器）的值，关闭A20，打开中断，回到原来的样子
LABLE_REAL_ENTRY:
	mov ax,cs
	mov es,ax
	mov ss,ax
	mov ds,ax
	
	mov sp,[SPValueInRealMode]
	
	in al,92h
	and al,11111101b	;关闭A20地址线
	out 92h,al
	
	sti					;打开中断
	mov ax,4c00h
	int 21h				;回到DOS
	
;32位代码段
[SECTION .s32]		
[BITS 32]
LABLE_SEG_CODE32:
	mov ax,SelectorData		;mov指令将数据从后者传递到前者
	mov ds,ax
	mov ax,SelectorTest
	mov es,ax
	mov ax,SelectorVideo
	mov gs,ax
	mov ax,SelectorStack
	mov ss,ax
	mov esp,TopOfStack
	;通过上面这段代码，ds是数据段寄存器，es，gs是附加段寄存器，ss是堆栈段寄存器，我们发现不能直接通过mov指令传递
	;数据到前面的寄存器，要先通过ax。通用寄存器有ax,bx,cx,dx
	
	;下面显示一个字符串
	mov ah,0Ch
	xor	esi,esi
	xor edi,edi
	mov esi,OffsetPMMessage		;数据源偏移
	mov edi,(80*10+0)*2			;目的数据源偏移，屏幕第10行，第0列
.1:
	lodsb
	test	al,al
	jz	.2
	mov	[gs:edi],ax
	add edi,2
	jmp .1
.2:			;显示完毕
	call DispReturn
	call TestRead
	call TestWrite
	call TestRead
	
	;到此停止
	jmp SelectorCode16:0		;跳到.s16Code
;load LDT
	mov ax,SelectorLDT
	lldt ax						;加载ldt
	
	jmp SelectorLDTCodeA:0		;跳入局部任务
	
;----------------------------------------
[SECTION .ldt]
ALIGN 32
LABLE_LDT:
;												段基址		段界限		  属性
LABLE_LDT_DESC_CODEA:			Descriptor			0,	CodeALen-1,		DA_C+DA_32		;code，32位
LDTLen		equ		$-LABLE_LDT

;LDT选择子
SelectorLDTCodeA	equ	LABLE_LDT_DESC_CODEA	-LABLE_GDT+SA_TIL
;END of [SECTION .ldt]

;CodeA (LDT32位代码段)
[SECTION .la]
ALIGN 32
[BITS 32]
LABLE_CODE_A:
	mov ax,SelectorVideo
	mov gs,ax
	
	mov edi,(80*12+0)*2
	mov ah,0Ch
	mov al,'L'
	mov [gs:edi],ax
	
	;准备由16位代码段跳回实模式
	jmp SelectorCode16:0
CodeALen	equ	$-LABLE_CODE_A
;END of [SECTION .la]
;------------------------------------
TestRead:
	xor	esi,esi
	mov ecx,8
.loop:
	mov al,[es:esi]
	call	DispAL
	inc esi
	loop .loop
	call	DispReturn
	ret
;TestRead结束

;------------------------------------
TestWrite:
	push	esi
	push	edi
	xor	esi,esi
	xor	edi,edi
	mov esi,OffsetStrTest
.1:
	lodsb
	test	al,al
	jz	.2
	mov	[es:edi],al
	inc edi
	jmp .1
	
.2:
	pop	edi
	pop	esi
	
	ret
;TestWrite结束
;-----------------------------------------
;显示AL中的数字
;默认的
;	数字已经存在al中
;	edi始终指向要显示的下一个字符的位置
;被改变的寄存器
;	ax,edi
;---------------------------------------------
DispAL:
	push ecx
	push edx
	
	mov ah,0Ch
	mov dl,al
	mov al,4
	mov ecx,2
.begin:
	and al,01111b
	cmp	al,9
	ja	.1
	add	al,'0'
	jmp .2
.1:
	sub	al,0Ah
	add al,'A'
.2:
	mov [gs:edi],ax
	add edi,2
	
	mov al,dl
	loop .begin
	add edi,2
	pop edx
	pop ecx
	
	ret
;DispAL结束---------------
;------------------------------------------------
DispReturn:
	push eax
	push ebx
	mov eax,edi
	mov bl,160
	div bl
	and	eax,0FFh
	inc eax
	mov bl,160
	mul bl
	mov edi,eax
	pop	ebx
	pop eax
	
	ret
;DispReturn结束----------------------

[SECTION .s16code]
ALIGN 32
[BITS 16]
LABLE_SEG_CODE16:
	;初始化LDT在GDT中的描述符
	xor eax,eax
	mov ax,ds
	shl eax,4
	add eax,LABLE_LDT
	mov word [LABLE_DESC_LDT+2],ax
	shr eax,16
	mov byte [LABLE_DESC_LDT+4],al
	mov byte [LABLE_DESC_LDT+7],ah
	
	;初始化LDT中的描述符
	xor eax,eax
	mov ax,ds
	shl eax,4
	add eax,LABLE_CODE_A
	mov word [LABLE_LDT_DESC_CODEA+2],ax
	shr eax,16
	mov byte [LABLE_LDT_DESC_CODEA+4],al
	mov byte [LABLE_LDT_DESC_CODEA+7],ah
	
	;跳回实模式
	mov ax,SelectorNormal
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax
	mov ss,ax
	
	mov eax,cr0			;这里清除了cr0的PE位，表示实模式
	and al,11111110b
	mov cr0,eax
	
LABLE_GO_BACK_TO_REAL:
	jmp 0:LABLE_REAL_ENTRY		;段地址在程序开始处被设置为正确的值
Code16Len	equ		$-LABLE_SEG_CODE16
;END OF [SECTION .s16Code]

