; PanchOS Kernel
; Pure 32-bit x86 Assembly / NASM
; Loaded by boot.asm at physical 0x10000.
;
; This is a tiny experimental kernel:
; - switches to 32-bit protected mode
; - writes directly to VGA memory
; - polls the PS/2 keyboard controller
; - implements a tiny command shell
;
; No C, C++, Rust, libc, BIOS services, or JavaScript.

bits 16
org 0x0000

kernel_start:
    cli

    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:protected_entry

bits 32
protected_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x90000

    call clear_screen
    call banner
    call prompt

main_loop:
    call keyboard_get
    cmp al, 0
    je main_loop

    cmp al, 0x08
    je handle_backspace

    cmp al, 0x0D
    je handle_enter

    cmp al, 32
    jb main_loop

    cmp byte [input_length], 63
    jae main_loop

    mov edi, input_buffer
    movzx ecx, byte [input_length]
    add edi, ecx
    mov [edi], al

    inc byte [input_length]
    call putc
    jmp main_loop

handle_backspace:
    cmp byte [input_length], 0
    je main_loop

    dec byte [input_length]
    mov al, 0x08
    call putc
    mov al, ' '
    call putc
    mov al, 0x08
    call putc
    jmp main_loop

handle_enter:
    call newline
    call execute_command
    mov byte [input_length], 0
    call prompt
    jmp main_loop

; ------------------------------------------------------------
; Screen
; ------------------------------------------------------------

clear_screen:
    pushad
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x0720
    rep stosw
    mov dword [cursor], 0
    popad
    ret

banner:
    mov esi, banner_text
    call puts
    ret

prompt:
    mov esi, prompt_text
    call puts
    ret

newline:
    mov al, 0x0D
    call putc
    mov al, 0x0A
    call putc
    ret

putc:
    push eax
    push ebx
    push edx

    cmp al, 0x0D
    je .carriage
    cmp al, 0x0A
    je .linefeed
    cmp al, 0x08
    je .backspace

    mov ebx, [cursor]
    cmp ebx, 80*25
    jb .write

    call scroll

.write:
    mov edx, 0xB8000
    lea edx, [edx + ebx*2]
    mov [edx], al
    mov byte [edx+1], 0x0F
    inc dword [cursor]
    jmp .done

.carriage:
    mov eax, [cursor]
    xor edx, edx
    mov ebx, 80
    div ebx
    sub [cursor], edx
    jmp .done

.linefeed:
    mov eax, [cursor]
    xor edx, edx
    mov ebx, 80
    div ebx
    inc eax
    imul eax, 80
    mov [cursor], eax
    cmp eax, 80*25
    jb .done
    call scroll
    jmp .done

.backspace:
    cmp dword [cursor], 0
    je .done
    dec dword [cursor]
    mov ebx, [cursor]
    mov edx, 0xB8000
    lea edx, [edx + ebx*2]
    mov word [edx], 0x0720

.done:
    pop edx
    pop ebx
    pop eax
    ret

puts:
.next:
    lodsb
    test al, al
    jz .done
    call putc
    jmp .next
.done:
    ret

scroll:
    pushad
    mov esi, 0xB8000 + 160
    mov edi, 0xB8000
    mov ecx, 80*24
    rep movsw

    mov ecx, 80
    mov ax, 0x0720
    rep stosw

    mov dword [cursor], 80*24
    popad
    ret

; ------------------------------------------------------------
; Keyboard
; ------------------------------------------------------------

keyboard_get:
.wait:
    in al, 0x64
    test al, 1
    jz .wait

    in al, 0x60
    test al, 0x80
    jnz .wait

    movzx eax, al
    cmp eax, 0x0E
    je .backspace
    cmp eax, 0x1C
    je .enter

    cmp eax, 0x39
    ja .no_key

    mov al, [scancode_table + eax]
    test al, al
    jz .no_key
    ret

.backspace:
    mov al, 0x08
    ret

.enter:
    mov al, 0x0D
    ret

.no_key:
    xor eax, eax
    ret

; Minimal US-layout set-1 scancode table.
scancode_table:
    db 0,0, '1','2','3','4','5','6','7','8','9','0','-','=',0,0
    db 'q','w','e','r','t','y','u','i','o','p','[',']',0,0
    db 'a','s','d','f','g','h','j','k','l',';',39,0,0,0
    db 'z','x','c','v','b','n','m',',','.','/',0,0,0,' '

; ------------------------------------------------------------
; Tiny shell
; ------------------------------------------------------------

execute_command:
    cmp byte [input_length], 0
    je .done

    mov esi, input_buffer
    mov edi, cmd_help
    call strcmp
    test eax, eax
    jz .help

    mov esi, input_buffer
    mov edi, cmd_clear
    call strcmp
    test eax, eax
    jz .clear

    mov esi, input_buffer
    mov edi, cmd_panchos
    call strcmp
    test eax, eax
    jz .panchos

    mov esi, input_buffer
    mov edi, cmd_reboot
    call strcmp
    test eax, eax
    jz .reboot

    mov esi, unknown_text
    call puts
    call newline
    jmp .done

.help:
    mov esi, help_text
    call puts
    jmp .done

.clear:
    call clear_screen
    jmp .done

.panchos:
    mov esi, panchos_text
    call puts
    jmp .done

.reboot:
    mov esi, reboot_text
    call puts
    call newline
    cli
    mov al, 0xFE
    out 0x64, al
    hlt
    jmp $

.done:
    ret

strcmp:
    push esi
    push edi
.next:
    mov al, [esi]
    mov dl, [edi]
    cmp al, dl
    jne .different
    test al, al
    jz .equal
    inc esi
    inc edi
    jmp .next
.different:
    mov eax, 1
    pop edi
    pop esi
    ret
.equal:
    xor eax, eax
    pop edi
    pop esi
    ret

; ------------------------------------------------------------
; GDT
; ------------------------------------------------------------

gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0x10000 + gdt_start

; ------------------------------------------------------------
; Data
; ------------------------------------------------------------

cursor dd 0
input_length db 0
input_buffer times 64 db 0

banner_text db 13,10, '========================================',13,10
            db '        PanchOS Assembly Edition       ',13,10
            db '========================================',13,10
            db 'Pure x86 Assembly // no userland yet',13,10,13,10,0

prompt_text db 'PanchOS> ',0
unknown_text db 'Comando no encontrado. Escribe help.',13,10,0

help_text db 'Comandos:',13,10
          db '  help     - muestra esta ayuda',13,10
          db '  clear    - limpia la pantalla',13,10
          db '  panchos  - informacion del sistema',13,10
          db '  reboot   - reinicia la maquina',13,10,0

panchos_text db 'PanchOS Assembly Edition',13,10
             db 'Arquitectura: x86 protected mode',13,10
             db 'Kernel: 100% Assembly',13,10
             db 'VGA: 0xB8000',13,10
             db 'Input: PS/2 polling',13,10,0

reboot_text db 'Reiniciando...',0
cmd_help db 'help',0
cmd_clear db 'clear',0
cmd_panchos db 'panchos',0
cmd_reboot db 'reboot',0

times 16384-($-$$) db 0
