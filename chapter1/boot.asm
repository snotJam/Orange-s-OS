;org: org指令指定程序起始地址；
;0100h：0100h是因为.com文件在DOS下，运行加载在0100h位置，前面的256个字节是程序段前缀PSP
;07c00h：开机后，默认寄存器CS=FFFFh，IP=0000h，工程师规定07c00h是引导程序开始的位置，即CS=0000h，IP=7c00h;
;0xAA55是结束位置
;任何操作系统启动后都要到引导盘中的07c00h位置加载引导程序，否则就是不正确的
%ifdef  _BOOT_DEBUG_
	org  0100h		; 调试状态, 做成 .COM 文件, 可调试
%else
	org  07c00h		; BIOS 将把 Boot Sector 加载到 0:7C00 处
%endif

;mov指令 传递指令，下面是将一个寄存器中的值传递到另一个寄存器
;寄存器，8086的寄存器都是16位的，可以存放2个字节
;cs,ip是8086cpu中最重要的两个寄存器，cpu将cs:ip指向的内容当作要执行的指令
;ax，通用寄存器，又称作累加器，使用频率最高
;cs,ds,es,ss都是段寄存器，存储段地址
	mov	ax, cs		;cs初始为0000h
	mov	ds, ax
	mov	es, ax		;至此，cs,ds,es,ax寄存器存储值都是0000h，可以看作将这几个寄存器初始化
	
;call指令：将当前运行指令的地址压入栈保存，然后跳转到指定的位置执行代码，比如这里就跳转到了DispStr位置执行
;那么也就说明不需要提前声明
	call	DispStr			; 调用显示字符串例程
	
;$表示当前行指令所在地址，jmp $就是一直跳到当前行地址，也就是死循环
	jmp	$			; 无限循环
	
;这里是call调用的位置
DispStr:
;这里按照之前的理解是将后面的值传递到ax，如果这里使用的是[BootMessage]，那么就是传递值
;这里更像是将BootMessage的地址传递给ax，因为asm中，不带[]的，都默认为地址
	mov	ax, BootMessage
;BP寄存器是堆栈基地址寄存器，一般配合SP使用的，SP是堆栈指针地址；
;ES:BP可以指向一个栈中的数据，下面的命令使得bp值为0000h
	mov	bp, ax			; ES:BP = 串地址
;cx值为16，cx位计数寄存器，下面16是BootMessage的长度
	mov	cx, 16			; CX = 串长度
;ax分为ah和al，高低位
	mov	ax, 01301h		; AH = 13,  AL = 01h
;bx也是通用寄存器
	mov	bx, 000ch		; 页号为0(BH = 0) 黑底红字(BL = 0Ch,高亮)
;dl，参考ax的ah和al，DX是数据寄存器
	mov	dl, 0
;int指令引发中断，int 10h表示屏幕显示，前面的都是中断操作之前的准备工作
;参考：https://www.cnblogs.com/magic-cube/archive/2011/10/19/2217676.html
	int	10h			; 10h 号中断
;ret指令，return，表示程序结束
	ret
	
;声明BootMessage，db表示定义byte类型数据，后面字符串中每一个字符都将占用一个byte
BootMessage:		db	"Hello, OS world!"
;times伪指令，重复执行指令
times 	510-($-$$)	db	0	; 填充剩下的空间，使生成的二进制代码恰好为512字节
;dw是一个伪指令，后面跟0xaa55表示引导程序结束
dw 	0xaa55				; 结束标志

;发现在notepad++中，伪指令是浅蓝细体；汇编指令是蓝色粗体

;######################################################################
;简单的引导程序：
;流程
;	规定引导程序起始位置
;	初始化寄存器
;	调用代码段-->代码段中做显示准备，int 10h中断，显示字符串，返回
;	times填充剩余空间
;	0xaa55结束引导程序
;注意点
;	0100h与07c00h区别
;	jmp $
;	ret
;	0xaa55
