; ==========================================
; pmtest1.asm
; 编译方法：nasm pmtest1.asm -o pmtest1.bin
; 这个是测试进入保护模式的
; ==========================================

%include	"pm.inc"	; 常量, 宏, 以及一些说明

	org	0100h
	jmp	LABEL_BEGIN
;[SECTION .gdt]定义一个名字为gdt的段后面同理
[SECTION .gdt]
; GDT
;下面部分是定义gdt中的变量，每一个变量指向一个Descriptor---段描述符，后面跟的值是对Descriptor初始化
;                              段基址,      段界限     , 属性
LABEL_GDT:	   Descriptor       0,                0, 0           ; 空描述符
LABEL_DESC_CODE32: Descriptor       0, SegCode32Len - 1, DA_C + DA_32; 非一致代码段
LABEL_DESC_VIDEO:  Descriptor 0B8000h,           0ffffh, DA_DRW	     ; 显存首地址
; GDT 结束

GdtLen		equ	$ - LABEL_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1	; GDT界限
		dd	0		; GDT基地址

; GDT 选择子
;实模式下直接使用段描述符的[段基址:偏移]找物理地址：GDT-->Descriptor-->段基址
;保护模式需要先从选择子中提取段描述符索引，再用索引在GDT中找到段描述符，用段描述符的[段基址:偏移]
;也就是保护模式下--Selector-->GDT-->Descriptor-->段基址
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; END of [SECTION .gdt]

;名字为s16的段
[SECTION .s16]
;告诉汇编器当作16位程序运行
[BITS	16]	
;段内代码块的名称
LABEL_BEGIN:
;初始化ax,ds,es,ss为0000h，sp为0100h
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	; 初始化 32 位的代码段描述符
	;eax为32位寄存器，xor eax,eax异或操作清零，效率比mov eax,0高
	xor	eax, eax
	mov	ax, cs
	;shl指令是左移指令，left，那么就是将eax中的数左移4位
	shl	eax, 4
	;add为加法指令，再加上描述符LABEL_SEG_CODE32的首地址
	add	eax, LABEL_SEG_CODE32
	;ax中的值将以每个数字占两个字节的方式传递到LABEL_DESC_CODE32基地址+2个字节的位置，汇编中+2表示2个字节
	;word表示一个字，占有两个字节
	;网上的解释为LABEL_DESC_CODE32 + 2正好指向Descriptor的 dw %1&0ffffh域，也就是基地址域
	mov	word [LABEL_DESC_CODE32 + 2], ax
	;shr指令右移指令,right，eax右移16位
	shr	eax, 16
	;参考mov word，这里是mov byte，是一个字节
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah
	;也就是说，到这里前面其实是设置了32位代码段描述符的参数

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

	; 准备切换到保护模式，cr0的值
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs,
					; 并跳转到 Code32Selector:0  处
; END of [SECTION .s16]


[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子(目的)

	mov	edi, (80 * 11 + 79) * 2	; 屏幕第 11 行, 第 79 列。
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'P'
	mov	[gs:edi], ax

	; 到此停止
	jmp	$

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]
;#################################################################
;简单的进入保护模式的程序。一般的开机后默认是实模式，我们系统启动后进入保护模式，我们的应用运行在保护模式下
;流程：
;	声明起始位置，jmp LABEL_BEGIN
;	定义gdt段，里面定义了段描述符和选择子
;	定义16位代码段，实模式下会运行16位代码段，jmp LABEL_BEGIN会跳到这里开始-->初始化寄存器--->初始化32位代码段描述符-->加载GDT-->关闭中断--
;		-->打开线地址A20-->切换到保护模式-->真正进入保护模式
;	定义32位代码段
;	我们看到，真正进入保护模式的代码是跳到SelectorCode32这个选择子的，根据选择子的用法，知道是根据选择子去GDT中
;		找了对应的段描述符就是LABEL_SEG_CODE32，也就是跳转到LABEL_SEG_CODE32这里执行了
;注意点
;	GDT，选择子与段描述符
;	cli关闭中断与A20避免回卷
;	cr0的值控制实模式到保护模式切换
;	jmp 选择子:0
;	SelectorVideo
