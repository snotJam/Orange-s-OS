	org 07c00h		;告诉编译器程序加载到7c00处
	mov ax,cs
	mov ds,ax
	mov es,ax
	call DispStr	;调用显示字符串的代码
	jmp $			;无限循环
DispStr:
	mov ax,BootMessage
	mov bp,ax		;ES:BP=串地址
	mov cx,16		;CX=串长度
	mov ax,01301h	;AH=13,AL=01h
	mov bx,000ch	;页号为0(BH=0)，黑底红字(BL=0CH，高亮)
	mov dl,0
	int 10h			;10h号中断
	ret
BootMessage:	db "Hello OS World"
times 510-($-$$) db 0		;填充剩余空间，使得二进制代码恰好为512字节
dw 0xaa55			;结束标志

;在汇编中，以分号开始注释，这个简单的引导程序通过命令加载到软盘的第一扇区，计算机启动以软盘启动的时候
;会检查这个扇区，发现是以0xaa55结束的时候，BIOS就认为它是一个引导扇区。然后将这512字节内容加载到0000:7c00处
;然后跳转到那个位置，控制权交给代码
;org指令告诉编译器代码加载的位置；2，3，4行通过mov指令使得ds,es这两个寄存器指向与cs相同的段，以便以后操作数据的时候定位准确
;call是调用指令；$是编译后当前行代码所在内存中的位置，jmp $就实现了无限循环
;int10 是BIOS提供的关于屏幕和显示器的操作指令
;$-$$就是当前位置与程序起始位置的相对差距，那么times 510-($-$$) db 0就是填充剩余空间为0（最后两个字节除外）
;dw 0xaa55也就是为最后两个字节赋值，这样BIOS检查的时候将这个512个字节扇区当作引导扇区加载到org指定的位置
