;段描述符
%macro Descriptor 3
	dw %2 & 0FFFFh		;段界限1
	dw %1 & 0FFFFh		;段基址1
	db (%1>>16) & 0FFh	;段基址2
	dw ((%2 >> 8) & 0FFh)|(%3 & 0F0FFh)		;属性1+段界限2+属性2
	db (%1>>24) & 0FFh	;段基址3
%endmacro		;共8字节

;门描述符
;usage	：Gate 	Selector,Offset,Dcount,Attr
;				Selector:dw---double word
;				Offset:dd---double double
;				Dcount:db---double byte
;				Attr:db
%macro Gate 3
	dw	(%2 & 0FFFFh)		;偏移1
	dw	%1					;选择子
	dw	(%3 & 1Fh) | {(%4 << 8) % 0FF00h}	;属性
	dw	{(%2 >> 16) & 0FFFFh}	;偏移2
%endmacro		;共8字节	
