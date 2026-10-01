# PanchOS Assembly Edition

Esta rama experimental reconstruye PanchOS como un sistema de arranque x86 escrito **únicamente en Assembly**.

## Componentes

- `boot.asm` — boot sector BIOS de 16 bits.
- `kernel.asm` — kernel de 32 bits en protected mode.
- VGA text mode directo mediante `0xB8000`.
- Entrada de teclado PS/2 mediante polling de puertos.
- Shell mínimo con `help`, `clear`, `panchos` y `reboot`.

No usa HTML, CSS, JavaScript, C, C++, Rust ni librerías externas en el código del sistema.

## Construcción

Requiere NASM y una herramienta para construir una imagen de disco.

1. Ensamblar el boot sector:
   `nasm -f bin boot.asm -o boot.bin`
2. Ensamblar el kernel:
   `nasm -f bin kernel.asm -o kernel.bin`
3. Crear una imagen de 1.44 MiB inicializada a cero y copiar `boot.bin` al primer sector.
4. Escribir `kernel.bin` a partir del sector 2.
5. Arrancar la imagen en una máquina virtual como QEMU.

> Esta es una rama de laboratorio. El kernel todavía no implementa multitarea, memoria virtual, filesystem real, drivers modernos, user mode ni un sistema de archivos persistente.
