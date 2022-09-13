[BITS 16]
[ORG 0x7C00]

struc MemoryMap
    .VideoBuffer resw 2000;
    .GameMap resb 2000; ;0xFA0 = B8FA0
    .GameState resb 1; ;B9770
    .Direction resb 1;
    .Seed resw 1;
    .VectorSize resw 1;
    .SnakeData resw 2000; lower = x, high = y;  B977A
endstruc

KEY_UP equ 72;
KEY_DOWN equ 80;
KEY_LEFT equ 75;
KEY_RIGHT equ 77;  
ESCAPE equ 16;

EMPTY equ 0;
FOOD equ 1;
SNAKE equ 2;

init:
    mov ax, 0xb800
    mov ds, ax
    mov bx, MemoryMap_size
    cli

zero_memory:
	dec bx
	mov byte [bx], 0
	jnz zero_memory

    mov ah, 0
	int 0x1A
	mov [MemoryMap.Seed], dx
    mov word [MemoryMap.GameState], 0x4d01
    ;inc byte [MemoryMap.GameState]
    ;mov byte [MemoryMap.Direction], KEY_RIGHT
    mov byte [MemoryMap.VectorSize], 2
    ;mov word [MemoryMap.SnakeData], 0xc28 ;start position at x=40, y=12
    ;mov word [MemoryMap.SnakeData + 2], 0xc27 ;start position at x= 40, y=12
    mov dword [MemoryMap.SnakeData], 0xc270c28
    ;mov dword [MemoryMap.VideoBuffer + 2 *(12 * 80 + 39)], 0x66206620
    ;mov word [MemoryMap.GameMap + 12 * 80 + 39], 0x0202
    call generateFood
    mov [cs:0x08*4], word timer_handler
	mov [cs:0x08*4+2], cs
    mov [cs:0x09*4], word keyboard_handler
	mov [cs:0x09*4+2], cs
    sti
	
main:
    hlt
    cmp byte [MemoryMap.GameState], 2
    je init
    jmp main

keyboard_handler:
    pusha
    in al, 0x60
    cmp al, ESCAPE
    jne snake_direction
    mov byte [MemoryMap.GameState], 2
    jmp endOfInterrupt
    
snake_direction:    
    mov bx, cs
    mov es, bx
    mov di, keyboard_directions
    mov cx, 4
    repne scasb
    jne endOfInterrupt
    mov bl, al
    xor bl, [MemoryMap.Direction]
    and bl, 1
    jz endOfInterrupt
	
assign:
    mov [MemoryMap.Direction],  al

endOfInterrupt:
    mov al, 0x20
    out 0x20, al    
    popa
    iret
	
; up:
;     cmp al, KEY_UP
;     jne down
;     cmp byte [MemoryMap.Direction], KEY_DOWN
;     je endOfInterrupt
;     jmp assign
; down:
;     cmp al, KEY_DOWN
;     jne left
;     cmp byte [MemoryMap.Direction], KEY_UP
;     je endOfInterrupt
;     jmp assign
; left:
;     cmp al, KEY_LEFT
;     jne right
;     cmp byte [MemoryMap.Direction], KEY_RIGHT
;     je endOfInterrupt
;     jmp assign
; right:
;     cmp al, KEY_RIGHT
;     jne endOfInterrupt
;     cmp byte [MemoryMap.Direction], KEY_LEFT
;     je endOfInterrupt


timer_handler:
    int 0x70
    inc word [cs:0x46c]
	
    cmp byte [MemoryMap.GameState], 1
    jne eoi

    mov bx, [MemoryMap.SnakeData]
    mov al, [MemoryMap.Direction]
    cmp byte al, KEY_UP
    jne $+4
    dec bh
    cmp byte al, KEY_DOWN
    jne $+4
    inc bh
    cmp byte al, KEY_LEFT
    jne $+4
    dec bl
    cmp byte al, KEY_RIGHT
    jne $+4
    inc bl

    cmp bl, 80
    jae lose
    cmp bh, 25
    jae lose

    mov al, 80
    mov cx, bx
    mul ch
    xor ch, ch
    add ax, cx
    mov si, ax
    
    cmp byte [si + MemoryMap.GameMap], SNAKE
    je lose
    
    cmp byte [si + MemoryMap.GameMap], FOOD
    je eatfood

    mov di, [MemoryMap.VectorSize]
    shl di, 1
    mov cx, [MemoryMap.SnakeData + di - 2]
    mov al, 80
    mul ch
    xor ch, ch
    add ax, cx
    mov di, ax

    mov byte [di + MemoryMap.GameMap], EMPTY
    dec word [MemoryMap.VectorSize]
	    
    jmp grow_snake

eatfood:
    call generateFood


grow_snake:
    mov cx, [MemoryMap.VectorSize]
    mov di, cx
    shl di, 1

copy_loop:    
    cmp cx, 0
    je insert
    mov ax, word [MemoryMap.SnakeData + di - 2]
    mov [MemoryMap.SnakeData + di], ax
    sub di, 2
    loop copy_loop


insert:    
    mov [MemoryMap.SnakeData], bx
    inc word [MemoryMap.VectorSize]
    mov byte [MemoryMap.GameMap + si], SNAKE


    mov cx, 80*25
    mov si, MemoryMap.GameState - 1
    mov di, MemoryMap.GameMap - 2

    xor bx, bx
    mov dx, 0x0020
draw:
    mov bl, [si]
    mov dh, [cs:bx+sprites]
    mov word [di], dx
    dec si
    sub di, 2

    loop draw
	
eoi:  
    iret
; draw:
;     mov al, [si]
; draw_empty:
;     cmp al, EMPTY
;     jne draw_food
;     mov word [di], 0x0020
;     jmp end_loop
; draw_food:
;     cmp al, FOOD 
;     jne draw_snake
;     mov word [di], 0x2220
;     jmp end_loop
; draw_snake:
;     mov word [di], 0x6620
; end_loop:
;     dec si
;     sub di, 2
;     loop draw

lose:
    mov byte [MemoryMap.GameState], 0
    xor ax, ax
    mov es, ax
    mov bp, lost_string
    mov ax, 0x1300
    mov bx, 0xc
    mov cx, 8
    mov dx, 0
    int 10h
    iret

; print_reg_16:
;     push ax
;     push bx
;     push dx
;     xor bx, bx
;     mov dx, ax
    
; switch:
;     mov ax, dx
;     cmp bx, 0
;     jne switch1
;     shr ah, 4
;     jmp a
; switch1:
;     cmp bx, 2
;     jne switch2
;     and ah, 15
;     jmp a

; switch2:
;     cmp bx, 4
;     jne switch3
;     shr al, 4
;     mov ah, al
;     jmp a

; switch3:
;     and al, 15
;     mov ah, al

; a:
;     cmp ah, 10
;     jl add_48
;     add ah, 55
;     jmp p
; add_48:
;     add ah, 48
; p: 
;     mov [MemoryMap.VideoBuffer + bx], ah
;     mov byte [MemoryMap.VideoBuffer + bx + 1], 0x0c
;     add bx, 2
;     cmp bx, 8
;     jne switch
;     pop dx
;     pop bx
;     pop ax
;     ret

random:
    push dx
    push cx
    mov ax, [MemoryMap.Seed]
	mov dx, 7993
	mov cx, 9781
	mul dx
	add ax, cx
	mov [MemoryMap.Seed], ax
    pop cx
    pop dx
    ret

generateFood:
    pusha
generation_loop: 
    call random
    xor dx, dx
    mov cx, 80
    div cx
    mov bl, dl
    call random
    xor dx, dx
    mov cx, 25
    div cx
    mov al, 80
    mul dl
    xor bh, bh
    add ax, bx
    mov di, ax
    cmp byte [di + MemoryMap.GameMap], SNAKE
    je generation_loop
    mov byte [di + MemoryMap.GameMap], FOOD
    popa
    ret

lost_string:
db 'You lose'
keyboard_directions:
db KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN
sprites:
db 0, 0x22, 0x66

;times 510-($-$$) db 0
;dw 0AA55h