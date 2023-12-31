[ORG 0x500]

[SECTION .data]
KERNEL_ADDR equ 0x1200

[SECTION .gdt]
SEG_BASE equ 0
SEG_LIMIT equ 0xfffff

CODE_SELECTOR equ (1 << 3)
DATA_SELECTOR equ (2 << 3)

gdt_base:
    dd 0, 0
gdt_code:
    dw SEG_LIMIT & 0xffff
    dw SEG_BASE & 0xffff
    db SEG_BASE >> 16 & 0xff
    ;P_DPL_S_TYPE
    db 0b1_00_1_1000
    ;G_DB_0_AVL_LIMIT
    db 0b0_1_0_0_0000 | (SEG_LIMIT >> 16 & 0xf)
    db SEG_BASE >> 24 & 0xf

gdt_data:
    dw SEG_LIMIT & 0xffff
    dw SEG_BASE & 0xffff
    db SEG_BASE >> 16 & 0xff
    ;P_DPL_S_TYPE
    db 0b1_00_1_0010
    ;G_DB_0_AVL_LIMIT
    db 0b0_1_0_0_0010 | (SEG_LIMIT >> 16 & 0xf)
    db SEG_BASE >> 24 & 0xf

gdt_ptr:
    dw $ - gdt_base
    dd gdt_base

[SECTION .text]
[BITS 16]
global setup_start
setup_start:
    xchg bx, bx
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov si, ax

    mov si, prepare_enter_protected_mode_msg
    call   print

enter_protected_mode:
    ; 关中断
    cli

    ; 加载gdt表
    xchg bx, bx
    lgdt [gdt_ptr]

    ; 开A20
    in    al,  92h
    or    al,  00000010b
    out   92h, al

    ; 设置保护模式
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp CODE_SELECTOR:protected_mode

print:
    mov ah, 0x0e
    mov bh, 0
    mov bl, 0x01
.loop:
    mov al, [si]
    cmp al, 0
    jz .done
    int 0x10

    inc si
    jmp .loop
.done:
    ret

[BITS 32]
protected_mode:
    xchg bx, bx
    mov ax, DATA_SELECTOR
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov esp, 0x9fbff

    ; 将内核读入内存
    mov edi, KERNEL_ADDR
    mov ecx, 3  ;从哪个山区开始读
    mov bl, 60  ;指定从硬盘读取的扇区数
    call read_hd

    jmp CODE_SELECTOR:KERNEL_ADDR    ;修改esi寄存器

read_hd:
    ; 0x1f2 8bit 指定读取或写入的扇区数
    mov dx, 0x1f2
    mov al, bl
    out dx, al

     ; 0x1f3 8bit iba地址的第八位 0-7
     inc dx
     mov al, cl
     out dx, al

     ; 0x1f4 8bit iba地址的中八位 8-15
     inc dx
     mov al, ch
     out dx, al

     ; 0x1f5 8bit iba地址的高八位 16-23
     inc dx
     shr ecx, 16
     mov al, cl
     out dx, al

     ; 0x1f6 8bit
     ; 0-3 位iba地址的24-27
     ; 4 0表示主盘 1表示从盘
     ; 5、7位固定为1
     ; 6 0表示CHS模式，1表示LAB模式
     inc dx
     mov al, ch
     add al, 0b1110_1111
     out dx, al

     ; 0x1f7 8bit  命令或状态端口
     inc dx
     mov al, 0x20
     out dx, al

     ; 设置loop次数，读多少个扇区要loop多少次
     mov cl, bl

.start_read:
    push cx     ; 保存loop次数，防止被下面的代码修改破坏

    call .wait_hd_prepare
    call read_hd_data

    pop cx      ; 恢复loop次数

    loop .start_read

.return:
    ret

; 一直等待，直到硬盘的状态是：不繁忙，数据已准备好
; 即第7位为0，第3位为1，第0位为0
.wait_hd_prepare:
     mov dx, 0x1f7
.check:
    in al, dx
    and al, 0b1000_1000
    cmp al, 0b0000_1000

    jnz .check

    ret


; 读硬盘，一次读两个字节，读256次，刚好读一个扇区
read_hd_data:
    mov dx, 0x1f0
    mov cx, 256

.read_word:
    in ax, dx
    mov [edi], ax
    add edi, 2
    loop .read_word

    ret

prepare_enter_protected_mode_msg:
    db "Prepare to go into protected mode...", 10, 13, 0