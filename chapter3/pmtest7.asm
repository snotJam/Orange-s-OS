;------------------------------------------------
;这段代码是在pmtest6上面修改了一部分
;用于测试获取内存信息
;-------------------------------------------
%include "pm.inc"		;常量，宏，以及一些说明

PageDirBase		equ 	200000h		;页目录开始地址
PageTblBase		equ		201000h		;页表开始地址

org 0100h
	jmp LABEL_BEGIN
	

[SECTION .gdt]
;GDT
;									段地址		段界限		  	属性
LABEL_GDT:			Descriptor			0,			0,			0		;空描述符
LABEL_NORMAL:		Descriptor			0,		0ffffh,			DA_DRW		;Normal描述符
LABEL_DESC_CODE32:	Descriptor			0,	SegCode32Len-1,		DA_C+DA_32	;非一致代码段 32
LABEL_DESC_CODE16:	Descriptor			0,		0ffffh,			DA_C		;非一致代码段 16
LABEL_DESC_DATA:	Descriptor			0,		DataLen-1,		DA_DRW		;Data
LABEL_DESC_STACK:	Descriptor			0,		TopOfStack,		DA_DRWA+DA_32	;stack 32位
LABEL_DESC_TEST:	Descriptor		05000000h,	0ffffh,			DA_DRW
LABEL_DESC_VIDEO:	Descriptor	  	0B8000h,	0ffffh,			DA_DRW		;显存首地址
;页地址
LABEL_DESC_PAGE_DIR:	Descriptor	PageDirBase, 4095,			DA_DRW		;Page Directory
LABEL_DESC_PAGE_TBL:	Descriptor	PageTblBase, 4096*8-1,		DA_DRW|DA_LIMIT_4K	;Page Tables
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
;页表的
SelectorPageDir	equ	LABEL_DESC_PAGE_DIR	-LABEL_GDT
SelectorPageTbl	equ	LABEL_DESC_PAGE_TBL	-LABEL_GDT
;end of [SECTION .gdt]

[SECTION .data1]	;数据段
	ALIGN	32
	[BIT 32]
	LABEL_DATA:		;这里定义了一些字符串和变量
		; 实模式下使用这些符号
			; 字符串
			_szPMMessage:			db	"In Protect Mode now. ^-^", 0Ah, 0Ah, 0	; 进入保护模式后显示此字符串
			_szMemChkTitle:			db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0	; 进入保护模式后显示此字符串
			_szRAMSize			db	"RAM size:", 0
			_szReturn			db	0Ah, 0
			; 变量
			_wSPValueInRealMode		dw	0
			_dwMCRNumber:			dd	0	; Memory Check Result
			_dwDispPos:			dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。
			_dwMemSize:			dd	0
			_ARDStruct:			; Address Range Descriptor Structure
				_dwBaseAddrLow:		dd	0
				_dwBaseAddrHigh:	dd	0
				_dwLengthLow:		dd	0
				_dwLengthHigh:		dd	0
				_dwType:		dd	0

			_MemChkBuf:	times	256	db	0

			; 保护模式下使用这些符号
			szPMMessage		equ	_szPMMessage	- $$
			szMemChkTitle		equ	_szMemChkTitle	- $$
			szRAMSize		equ	_szRAMSize	- $$
			szReturn		equ	_szReturn	- $$
			dwDispPos		equ	_dwDispPos	- $$
			dwMemSize		equ	_dwMemSize	- $$
			dwMCRNumber		equ	_dwMCRNumber	- $$
			ARDStruct		equ	_ARDStruct	- $$
				dwBaseAddrLow	equ	_dwBaseAddrLow	- $$
				dwBaseAddrHigh	equ	_dwBaseAddrHigh	- $$
				dwLengthLow	equ	_dwLengthLow	- $$
				dwLengthHigh	equ	_dwLengthHigh	- $$
				dwType		equ	_dwType		- $$
			MemChkBuf		equ	_MemChkBuf	- $$

			DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]
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

	;得到内存数
	mov ebx,0			;ebx为0
	mov di,_MemChkBuf
.loop:
	mov eax,0E820h		;要想获取内存大小，需要先将ax赋值为0E820h
	mov ecx,20
	mov edx,0534D4150h	;第一此循环开始前需要eax=0E820h，ebx=0,ecx=20,edx=0534D4150h，es:di指向_MemChkBuf的开始处
	int 15h				;中断15h
	jc	LABEL_MEM_CHK_FAIL		
	add di,20			;每执行一次循环，di增量位20字节，而eax,ecx,edx值不会变，而不在乎ebx的值
	inc dword [_dwMCRNumber]	;每次循环_dwMCRNumber的值加1，循环结束的时候这个值就是循环的次数,也是地址范围描述符个数
	cmp ebx,0
	jne .loop
	jmp LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
	mov dword [_dwMCRNumber],0
LABEL_MEM_CHK_OK:
	
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
	push szPMMessage
	call DispStr
	add esp,4
	
	push szMemChkTitle
	call DispStr
	add esp,4
	
	call	DispMemSize		; 显示内存信息

	call	SetupPaging		; 启动分页机制
	;到此停止
	jmp SelectorCode16:0		;跳到.s16Code
;------------------------------------

;------------------------------------------
;启动分页机制
SetupPaging:
	; 根据内存大小计算应初始化多少PDE以及多少页表
	xor edx,edx
	mov eax,[dwMemSize]
	mov ebx,400000h				;400000h=4M，是一个页表对应的内存的大小
	div ebx
	mov ecx,eax					;此时ecx为PDE应该的个数
	test edx,edx				
	js .no_remainder
	inc ecx						;如果余数不为0，增加一个页表
.no_remainder
	push	ecx		; 暂存页表个数

	; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空洞.

	; 首先初始化页目录
	mov	ax, SelectorPageDir	; 此段首地址为 PageDirBase
	mov	es, ax
	xor	edi, edi
	xor	eax, eax
	mov	eax, PageTblBase | PG_P  | PG_USU | PG_RWW
.1:
	stosd		;这个指令执行的时候，将eax中的PageTblBae PG_P | PG_USU | PG_RWW存入页目录表的第一个PDE、
				;当为第一个PDE赋值的时候，一个循环就开始了，循环的每一次，es:edi都指向下一个PDE
	add eax,4096	;将下一个页表的首地址增加了4096字节，以便与上一个页表首位相接。
					;经过1024次循环，将所有PDE赋值
	loop .1
	
	;再初始化所有页表
	mov ax,SelectorPageTbl	;同上，上面的是PDE赋值，那么这里就是PTE的赋值
	mov es,ax
	mov ecx,1024*1024
	xor edi,edi
	xor eax,eax
	mov eax,PG_P | PG_USU | PG_RWW
.2
	stosd
	add eax,4096
	loop .2
	
	mov eax,PageDirBase
	mov cr3,eax			;首先让cr3指向页表目录
	mov eax,cr0			;设置cr0的PG，启动分页机制
	or eax,80000000h
	mov cr0,eax
	jmp short .3
.3
	nop
	
	ret
;分页基址启动完毕
;------------------------------------------------
;保护模式下32位代码，显示内存信息
DispMemSize:
	push	esi
	push	edi
	push	ecx

	mov	esi, MemChkBuf
	mov	ecx, [dwMCRNumber];for(int i=0;i<[MCRNumber];i++)//每次得到一个ARDS
.loop:				  ;{
	mov	edx, 5		  ;  for(int j=0;j<5;j++) //每次得到一个ARDS中的成员
	mov	edi, ARDStruct	  ;  {//依次显示BaseAddrLow,BaseAddrHigh,LengthLow,
.1:				  ;             LengthHigh,Type
	push	dword [esi]	  ;
	call	DispInt		  ;    DispInt(MemChkBuf[j*4]); //显示一个成员
	pop	eax		  ;
	stosd			  ;    ARDStruct[j*4] = MemChkBuf[j*4];
	add	esi, 4		  ;
	dec	edx		  ;
	cmp	edx, 0		  ;
	jnz	.1		  ;  }
	call	DispReturn	  ;  printf("\n");
	cmp	dword [dwType], 1 ;  if(Type == AddressRangeMemory)
	jne	.2		  ;  {
	mov	eax, [dwBaseAddrLow];
	add	eax, [dwLengthLow];
	cmp	eax, [dwMemSize]  ;    if(BaseAddrLow + LengthLow > MemSize)
	jb	.2		  ;
	mov	[dwMemSize], eax  ;    MemSize = BaseAddrLow + LengthLow;
.2:				  ;  }
	loop	.loop		  ;}
				  ;
	call	DispReturn	  ;printf("\n");
	push	szRAMSize	  ;
	call	DispStr		  ;printf("RAM size:");
	add	esp, 4		  ;
				  ;
	push	dword [dwMemSize] ;
	call	DispInt		  ;DispInt(MemSize);
	add	esp, 4		  ;

	pop	ecx
	pop	edi
	pop	esi
	ret

%include	"lib.inc"	; 库函数lib.inc

;------------------------------------------

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

	