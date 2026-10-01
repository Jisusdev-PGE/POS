; PanchOS — BIOS boot sector
; Pure x86 Assembly / NASM
; Loads the second-stage kernel at physical address 0x10000
; and transfers control to it.

bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    ; Reset disk
    xor ah, ah
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Load 32 sectors (16 KiB) to 0x1000:0000 = 0x10000.
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    jmp 0x1000:0x0000

disk_error:
    mov si, disk_msg
.print:
    lodsb
    or al, al
    jz .halt
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .print
.halt:
    cli
    hlt
    jmp .halt

boot_drive db 0
disk_msg db 'PanchOS boot error.', 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55
