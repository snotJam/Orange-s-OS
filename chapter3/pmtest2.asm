;这段代码是在pmtest1上面修改了一部分
%include "pm.inc"		;常量，宏，以及一些说明

org 0100h
	jmp LABEL_BEGIN
	
[SECTION .gdt]
;GDT
;									段地址		段界限		  属性
LABEL_GDT:			Descriptor			0,			0,			0		;空描述符
LABEL_NORMAL:		Descriptor			0,		0ffffh,			DA_DRW		;Normal描述符
LABEL_DESC_CODE32:	Descriptor			0,	SegCode32Len-1,		DA_C+DA_32	;非一致代码段 32
LABEL_DESC_CODE16:	Descriptor			0,		0ffffh,			DA_C		;非一致代码段 16
LABEL_DESC_DATA:	Descriptor			0,		DataLen-1,		DA_DRW		;Data
LABEL_DESC_STACK:	Descriptor			0,		TopOfStack,		DA_DRWA+DA_32	;stack 32位
LABEL_DESC_TEST:	Descriptor		05000000h,	0ffffh,			DA_DRW
LABEL_DESC_VIDEO:	Descriptor	  	0B8000h,	0ffffh,			DA_DRW		;显存首地址
;GDT结束

GdtLen	equ	$-LABEL_GDT		;GDT长度
GdtPtr	dw	GdtLen-1		;GDT界限
		dd	0				;GDT基地址

;GDT选择子
SelectorNormal	equ	LABEL_DESC_CODE32	-LABEL_GDT
SelectorCode32	equ	LABEL_DESC_CODE32	-LABEL_GDT
SelectorCode16	equ	LABEL_DESC_CODE16	-LABEL_GDT
SelectorData	equ	LABEL_DESC_DATA		-LABEL_GDT
SelectorStack	equ	LABEL_DESC_STACK	-LABEL_GDT
SelectorTest	equ	LABEL_DESC_TEST		-LABEL_GDT
SelectorVideo	equ	LABEL_DESC_VIDEO	-LABEL_GDT
;end of [SECTION .gdt]

[SECTION .data1]	;数据段
	ALIGN	32
	[BIT 32]
	LABEL_DATA:
		SPValueInRealMode	dw	0
		;字符串
		PMMessage:			db "In Project Mode now ^-^", 0		;在保护模式中显示
		OffsetPMMessage		equ	PMMessage-$$
		StrTest:			db	"ABCDEFGHIJKLMN",0
		OffsetStrTest		equ	StrTest-$$
		DataLen				equ	$-LABEL_DATA
;END of [SECTION .data1]

;全局堆栈段
[SECTION .gs]		
	ALIGN	32
	[BIT 32]
	LABEL_STACK:
		times 512 db 0
	TopOfStack		equ 	$-LABEL_STACK-1
;END of [SECTION .gs]

[SECTION .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	mov	[LABEL_GO_BACK_TO_REAL+3], ax	;LABEL_GO_BACK_TO_REAL+3刚好是Segment的地址
										;此处先将cs值给了ax，最后又将ax中的值给了Segment，也就是此时segment地址为cs值
										;那么代码jmp 0,LABEL_REAL_ENTRY就变成了jmp cs_real_mode:LABEL_REAL_ENTRY
										;将跳到标号LABEL_REAL_ENTRY处
	mov	[SPValueInRealMode], sp

	; 初始化 16 位代码段描述符
	mov	ax, cs
	movzx	eax, ax
	shl	eax, 4
	add	eax, LABEL_SEG_CODE16
	mov	word [LABEL_DESC_CODE16 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE16 + 4], al
	mov	byte [LABEL_DESC_CODE16 + 7], ah

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 初始化堆栈段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah

	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处
											

;初始化段描述符
xor	eax,eax
mov ax,ds
mov eax,4
add eax,LABEL_DATA
mov word [LABEL_DESC_DATA+2],ax
shr eax,16
mov byte [LABEL_DESC_DATA+4],al
mov byte [LABEL_DESC_DATA+7],ah

;在跳回实模式后，将重置各寄存器的值，恢复sp（堆栈寄存器）的值，关闭A20，打开中断，回到原来的样子
LABEL_REAL_ENTRY:
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
LABEL_SEG_CODE32:
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
LABEL_SEG_CODE16:
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
	
LABEL_GO_BACK_TO_REAL:
	jmp 0:LABEL_REAL_ENTRY		;段地址在程序开始处被设置为正确的值
Code16Len	equ		$-LABEL_SEG_CODE16
;END OF [SECTION .s16Code]

	