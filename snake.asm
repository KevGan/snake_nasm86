; =============================================================================
; Juego de la Serpiente (Snake Game) - NASM x86 Real Mode
; =============================================================================
; Compilar con: nasm -f bin snake.asm -o snake.com
; Ejecutar en DOSBox o entorno DOS compatible
; =============================================================================

org 100h                    ; COM file format

; =============================================================================
; Constantes del juego
; =============================================================================
ROWS        equ 25          ; Filas de la pantalla
COLS        equ 80          ; Columnas de la pantalla
MAX_LEN     equ 32          ; Longitud máxima de la serpiente
START_LEN   equ 3           ; Longitud inicial de la serpiente

; Área jugable (dentro de los bordes)
PLAY_MIN_ROW equ 4          ; Fila mínima jugable
PLAY_MAX_ROW equ 22         ; Fila máxima jugable
PLAY_MIN_COL equ 2          ; Columna mínima jugable
PLAY_MAX_COL equ 77         ; Columna máxima jugable

; Centro del área de juego (para posición inicial y fallback)
CENTER_X     equ 40
CENTER_Y     equ 13

; Direcciones
DIR_UP      equ 0
DIR_DOWN    equ 1
DIR_LEFT    equ 2
DIR_RIGHT   equ 3

; Colores
COLOR_BG        equ 0x00    ; Fondo negro
COLOR_BORDER    equ 0x0F    ; Borde blanco
COLOR_SNAKE     equ 0x0A    ; Serpiente verde brillante
COLOR_FOOD      equ 0x0C    ; Comida rojo brillante
COLOR_TEXT      equ 0x0F    ; Texto blanco
COLOR_TITLE     equ 0x0E    ; Título amarillo
COLOR_VICTORY   equ 0x0E    ; Victoria amarillo brillante
COLOR_GAMEOVER  equ 0x0C    ; Game over rojo

; Teclas
KEY_ESC     equ 27
KEY_UP      equ 72
KEY_DOWN    equ 80
KEY_LEFT    equ 75
KEY_RIGHT   equ 77
KEY_ENTER   equ 13

; Estados del juego
STATE_MENU      equ 0
STATE_PLAYING   equ 1
STATE_GAMEOVER  equ 2
STATE_VICTORY   equ 3
STATE_ESC       equ 0FFh    ; Estado especial para ESC

; Límite de intentos para colocar comida
MAX_FOOD_ATTEMPTS equ 100

; =============================================================================
; Inicio del programa
; =============================================================================
main:
    ; Configurar modo de video 80x25 texto color
    mov ax, 0003h
    int 10h
    
    ; Ocultar cursor
    mov ah, 01h
    mov cx, 2000h
    int 10h
    
    ; Inicializar generador de números aleatorios
    call init_random

menu_loop:
    call show_menu
    call wait_for_key
    
    cmp al, KEY_ESC
    je exit_game
    cmp al, KEY_ENTER
    je start_game
    cmp ah, KEY_ENTER
    je start_game
    jmp menu_loop

start_game:
    call init_game
    call game_loop
    
    ; Verificar si fue victoria o game over
    mov al, [game_over_flag]
    cmp al, STATE_VICTORY
    je .show_victory
    cmp al, STATE_GAMEOVER
    je .show_gameover
    jmp menu_loop           ; ESC presionado, volver al menú

.show_victory:
    call show_victory
    call wait_for_key
    jmp menu_loop

.show_gameover:
    call show_game_over
    call wait_for_key
    jmp menu_loop

exit_game:
    ; Restaurar modo de video y cursor
    mov ax, 0003h
    int 10h
    
    ; Salir a DOS
    mov ax, 4C00h
    int 21h

; =============================================================================
; Inicializar generador de números aleatorios
; Usa XOR de CX y DX del timer BIOS para mejor entropía
; =============================================================================
init_random:
    push cx
    push dx
    
    mov ah, 00h
    int 1Ah                 ; Obtener tick count del BIOS
    xor dx, cx              ; XOR ambas partes para mejor entropía
    mov [rand_seed], dx
    
    pop dx
    pop cx
    ret

; =============================================================================
; Generar número aleatorio
; Entrada: ninguna
; Salida: AX = número aleatorio
; =============================================================================
random:
    push dx
    
    mov ax, [rand_seed]
    mov dx, 25173
    mul dx
    add ax, 13849
    mov [rand_seed], ax
    
    pop dx
    ret

; =============================================================================
; Generar número aleatorio en rango
; Entrada: CX = límite superior (exclusivo)
; Salida: AX = número aleatorio [0, CX)
; =============================================================================
random_range:
    call random
    xor dx, dx
    div cx                  ; DX = AX mod CX
    mov ax, dx
    ret

; =============================================================================
; Mostrar menú principal
; =============================================================================
show_menu:
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Limpiar pantalla
    call clear_screen
    
    ; Dibujar borde
    call draw_border
    
    ; Título del juego
    mov dh, 5
    mov dl, 30
    call set_cursor
    mov si, title_str
    mov bl, COLOR_TITLE
    call print_string
    
    ; Instrucciones
    mov dh, 10
    mov dl, 25
    call set_cursor
    mov si, instructions1_str
    mov bl, COLOR_TEXT
    call print_string
    
    mov dh, 12
    mov dl, 25
    call set_cursor
    mov si, instructions2_str
    call print_string
    
    mov dh, 14
    mov dl, 25
    call set_cursor
    mov si, instructions3_str
    call print_string
    
    ; Mostrar puntuación máxima
    mov dh, 18
    mov dl, 28
    call set_cursor
    mov si, high_score_str
    mov bl, COLOR_TITLE
    call print_string
    mov ax, [high_score]
    call print_number
    
    ; Mensaje de inicio
    mov dh, 22
    mov dl, 23
    call set_cursor
    mov si, press_enter_str
    mov bl, COLOR_TEXT
    call print_string
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Inicializar juego
; =============================================================================
init_game:
    push ax
    push bx
    push cx
    push si
    push di
    
    ; Resetear variables
    mov byte [game_over_flag], 0
    mov byte [direction], DIR_RIGHT
    mov byte [next_direction], DIR_RIGHT
    mov word [score], 0
    mov byte [snake_length], START_LEN
    
    ; Inicializar posición de la serpiente en el centro
    mov word [snake_x], 40
    mov word [snake_x + 2], 39
    mov word [snake_x + 4], 38
    
    mov word [snake_y], 12
    mov word [snake_y + 2], 12
    mov word [snake_y + 4], 12
    
    ; Limpiar el resto del arreglo de la serpiente
    mov cx, MAX_LEN - START_LEN
    mov di, snake_x + 6
    xor ax, ax
.clear_snake_x:
    mov [di], ax
    add di, 2
    loop .clear_snake_x
    
    mov cx, MAX_LEN - START_LEN
    mov di, snake_y + 6
.clear_snake_y:
    mov [di], ax
    add di, 2
    loop .clear_snake_y
    
    ; Limpiar pantalla y dibujar borde
    call clear_screen
    call draw_border
    
    ; Colocar comida
    call place_food_random
    
    ; Dibujar serpiente inicial
    call draw_snake
    
    ; Mostrar puntuación
    call draw_score
    
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Bucle principal del juego
; =============================================================================
game_loop:
    push ax
    push bx
    push cx
    push dx

.loop:
    ; Verificar si el juego terminó
    cmp byte [game_over_flag], 0
    jne .exit
    
    ; Procesar entrada del teclado
    call process_input
    
    ; Verificar si se presionó ESC
    cmp byte [game_over_flag], 0
    jne .exit
    
    ; Actualizar dirección
    mov al, [next_direction]
    mov [direction], al
    
    ; Mover serpiente
    call move_snake
    
    ; Verificar colisiones
    call check_collision
    
    ; Verificar si el juego terminó
    cmp byte [game_over_flag], 0
    jne .exit
    
    ; Verificar si comió comida
    call check_food
    
    ; Dibujar serpiente
    call draw_snake
    
    ; Dibujar comida
    call draw_food
    
    ; Mostrar puntuación
    call draw_score
    
    ; Delay para controlar velocidad
    call game_delay
    
    jmp .loop

.exit:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Procesar entrada del teclado
; =============================================================================
process_input:
    push ax
    push bx
    
    ; Verificar si hay tecla disponible
    mov ah, 01h
    int 16h
    jz .no_key
    
    ; Leer tecla
    mov ah, 00h
    int 16h
    
    ; Verificar ESC
    cmp al, KEY_ESC
    je .escape
    
    ; Verificar teclas de flecha (código de escaneo en AH)
    cmp ah, KEY_UP
    je .up
    cmp ah, KEY_DOWN
    je .down
    cmp ah, KEY_LEFT
    je .left
    cmp ah, KEY_RIGHT
    je .right
    
    jmp .no_key

.escape:
    mov byte [game_over_flag], STATE_ESC    ; Estado especial para ESC
    jmp .done

.up:
    ; No permitir ir hacia abajo si está yendo hacia arriba
    cmp byte [direction], DIR_DOWN
    je .no_key
    mov byte [next_direction], DIR_UP
    jmp .done

.down:
    ; No permitir ir hacia arriba si está yendo hacia abajo
    cmp byte [direction], DIR_UP
    je .no_key
    mov byte [next_direction], DIR_DOWN
    jmp .done

.left:
    ; No permitir ir hacia derecha si está yendo hacia izquierda
    cmp byte [direction], DIR_RIGHT
    je .no_key
    mov byte [next_direction], DIR_LEFT
    jmp .done

.right:
    ; No permitir ir hacia izquierda si está yendo hacia derecha
    cmp byte [direction], DIR_LEFT
    je .no_key
    mov byte [next_direction], DIR_RIGHT
    jmp .done

.no_key:
.done:
    pop bx
    pop ax
    ret

; =============================================================================
; Mover serpiente
; =============================================================================
move_snake:
    push ax
    push bx
    push cx
    push si
    push di
    
    ; Mover cuerpo (desde la cola hacia la cabeza)
    movzx cx, byte [snake_length]
    dec cx                  ; CX = índice del último segmento
    
.move_body:
    cmp cx, 0
    je .move_head
    
    ; snake_x[i] = snake_x[i-1]
    mov si, cx
    dec si
    shl si, 1               ; SI = (i-1) * 2
    mov di, cx
    shl di, 1               ; DI = i * 2
    
    mov ax, [snake_x + si]
    mov [snake_x + di], ax
    mov ax, [snake_y + si]
    mov [snake_y + di], ax
    
    dec cx
    jmp .move_body

.move_head:
    ; Mover cabeza según dirección
    mov al, [direction]
    
    cmp al, DIR_UP
    je .head_up
    cmp al, DIR_DOWN
    je .head_down
    cmp al, DIR_LEFT
    je .head_left
    ; DIR_RIGHT por defecto
    
.head_right:
    inc word [snake_x]
    jmp .done

.head_up:
    dec word [snake_y]
    jmp .done

.head_down:
    inc word [snake_y]
    jmp .done

.head_left:
    dec word [snake_x]

.done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Verificar colisiones con bordes y cuerpo
; Área jugable: filas 4-22, columnas 2-77 (inclusive)
; Bordes: fila 3 (arriba), fila 23 (abajo), columna 1 (izq), columna 78 (der)
; =============================================================================
check_collision:
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Obtener posición de la cabeza
    mov ax, [snake_x]       ; DL = columna
    mov dx, ax
    mov ax, [snake_y]       ; BL = fila
    mov bx, ax
    
    ; Verificar colisión con bordes usando constantes
    ; Si la posición es menor que el área jugable mínima = colisión
    cmp bl, PLAY_MIN_ROW
    jb .hit
    
    ; Si la posición es mayor que el área jugable máxima = colisión
    cmp bl, PLAY_MAX_ROW
    ja .hit
    
    ; Si la columna es menor que el área jugable mínima = colisión
    cmp dl, PLAY_MIN_COL
    jb .hit
    
    ; Si la columna es mayor que el área jugable máxima = colisión
    cmp dl, PLAY_MAX_COL
    ja .hit
    
    ; Verificar colisión con cuerpo
    movzx cx, byte [snake_length]
    dec cx                  ; No verificar la cabeza consigo misma
    cmp cx, 0
    je .no_collision
    
    mov si, 2               ; Empezar desde el segundo segmento

.check_body:
    cmp cx, 0
    je .no_collision
    
    mov ax, [snake_x + si]
    cmp dx, ax
    jne .next_segment
    
    mov ax, [snake_y + si]
    cmp bx, ax
    je .hit

.next_segment:
    add si, 2
    dec cx
    jmp .check_body

.hit:
    mov byte [game_over_flag], STATE_GAMEOVER
    ; Actualizar puntuación máxima
    call update_high_score

.no_collision:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Verificar si la serpiente comió comida
; =============================================================================
check_food:
    push ax
    push bx
    
    ; Verificar si la cabeza está en la posición de la comida
    mov ax, [snake_x]
    cmp ax, [food_x]
    jne .no_food
    
    mov ax, [snake_y]
    cmp ax, [food_y]
    jne .no_food
    
    ; ¡Comió comida!
    inc word [score]
    
    ; Crecer serpiente si no está en máximo (caso de seguridad)
    cmp byte [snake_length], MAX_LEN
    jae .already_max            ; Si ya está en máximo, verificar victoria
    
    ; Crecer la serpiente
    inc byte [snake_length]
    
    ; Verificar si ahora alcanzó la longitud máxima para victoria
    cmp byte [snake_length], MAX_LEN
    je .victory                 ; Alcanzó MAX_LEN = victoria
    
    ; Aún no está en máximo, colocar nueva comida
    jmp .place_new_food

.already_max:
    ; Ya estaba en MAX_LEN (caso de seguridad que no debería ocurrir normalmente)
.victory:
    mov byte [game_over_flag], STATE_VICTORY
    call update_high_score
    jmp .done

.place_new_food:
    ; Colocar nueva comida
    call place_food_random

.no_food:
.done:
    pop bx
    pop ax
    ret

; =============================================================================
; Colocar comida en posición aleatoria
; Con contador de reintentos para evitar bucle infinito (máx 100 intentos)
; =============================================================================
place_food_random:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov byte [retry_counter], MAX_FOOD_ATTEMPTS   ; Máximo de intentos

.try_place:
    ; Verificar contador de reintentos
    dec byte [retry_counter]
    cmp byte [retry_counter], 0
    je .force_place             ; Si se agotaron los intentos, forzar colocación
    
    ; Generar posición X aleatoria usando constantes
    mov cx, PLAY_MAX_COL - PLAY_MIN_COL + 1  ; Rango: 0-(MAX-MIN)
    call random_range
    add ax, PLAY_MIN_COL        ; Ajustar a rango válido
    mov [food_x], ax
    
    ; Generar posición Y aleatoria usando constantes
    mov cx, PLAY_MAX_ROW - PLAY_MIN_ROW + 1  ; Rango: 0-(MAX-MIN)
    call random_range
    add ax, PLAY_MIN_ROW        ; Ajustar a rango válido
    mov [food_y], ax
    
    ; Verificar que no esté sobre la serpiente
    movzx cx, byte [snake_length]
    xor si, si

.check_snake:
    cmp cx, 0
    je .valid_position
    
    mov ax, [snake_x + si]
    cmp ax, [food_x]
    jne .next
    
    mov ax, [snake_y + si]
    cmp ax, [food_y]
    je .try_place               ; Está sobre la serpiente, intentar de nuevo

.next:
    add si, 2
    dec cx
    jmp .check_snake

.force_place:
    ; Forzar colocación en posición fija si se agotaron los intentos
    ; Usa constantes del centro del área de juego
    mov word [food_x], CENTER_X
    mov word [food_y], CENTER_Y

.valid_position:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Dibujar serpiente
; =============================================================================
draw_snake:
    push ax
    push bx
    push cx
    push dx
    push si
    
    xor si, si                      ; SI = índice actual * 2 (offset en bytes)
    movzx cx, byte [snake_length]   ; CX = número de segmentos a dibujar

.draw_loop:
    cmp cx, 0
    je .done
    
    ; Posicionar cursor
    mov ax, [snake_y + si]
    mov dh, al
    mov ax, [snake_x + si]
    mov dl, al
    call set_cursor
    
    ; Guardar contador en stack antes de usar CX para BIOS
    push cx
    
    ; Dibujar segmento (cabeza o cuerpo)
    mov ah, 09h
    cmp si, 0
    jne .draw_body
    
    ; Cabeza (primer segmento)
    mov al, '@'
    jmp .do_draw

.draw_body:
    ; Cuerpo
    mov al, 'o'

.do_draw:
    mov bh, 0
    mov bl, COLOR_SNAKE
    mov cx, 1
    int 10h
    
    ; Restaurar contador y avanzar al siguiente segmento
    pop cx
    add si, 2
    dec cx
    jmp .draw_loop

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Dibujar comida
; =============================================================================
draw_food:
    push ax
    push bx
    push cx
    push dx
    
    mov ax, [food_y]
    mov dh, al
    mov ax, [food_x]
    mov dl, al
    call set_cursor
    
    mov ah, 09h
    mov al, '*'
    mov bh, 0
    mov bl, COLOR_FOOD
    mov cx, 1
    int 10h
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Dibujar puntuación
; =============================================================================
draw_score:
    push ax
    push bx
    push dx
    push si
    
    mov dh, 1
    mov dl, 2
    call set_cursor
    
    mov si, score_str
    mov bl, COLOR_TEXT
    call print_string
    
    mov ax, [score]
    call print_number
    
    ; Mostrar longitud
    mov dh, 1
    mov dl, 20
    call set_cursor
    mov si, length_str
    call print_string
    
    movzx ax, byte [snake_length]
    call print_number
    
    pop si
    pop dx
    pop bx
    pop ax
    ret

; =============================================================================
; Mostrar pantalla de Game Over
; =============================================================================
show_game_over:
    push ax
    push bx
    push dx
    push si
    
    ; Mensaje de game over
    mov dh, 13
    mov dl, 30
    call set_cursor
    
    mov si, game_over_str
    mov bl, COLOR_GAMEOVER
    call print_string
    
    ; Puntuación final
    mov dh, 15
    mov dl, 28
    call set_cursor
    mov si, final_score_str
    mov bl, COLOR_TEXT
    call print_string
    mov ax, [score]
    call print_number
    
    ; Mensaje para continuar
    mov dh, 18
    mov dl, 20
    call set_cursor
    mov si, press_key_str
    call print_string
    
    pop si
    pop dx
    pop bx
    pop ax
    ret

; =============================================================================
; Mostrar pantalla de Victoria
; =============================================================================
show_victory:
    push ax
    push bx
    push dx
    push si
    
    ; Mensaje de victoria
    mov dh, 13
    mov dl, 22
    call set_cursor
    
    mov si, victory_str
    mov bl, COLOR_VICTORY
    call print_string
    
    ; Puntuación final
    mov dh, 15
    mov dl, 28
    call set_cursor
    mov si, final_score_str
    mov bl, COLOR_TEXT
    call print_string
    mov ax, [score]
    call print_number
    
    ; Mensaje para continuar
    mov dh, 18
    mov dl, 20
    call set_cursor
    mov si, press_key_str
    call print_string
    
    pop si
    pop dx
    pop bx
    pop ax
    ret

; =============================================================================
; Actualizar puntuación máxima
; =============================================================================
update_high_score:
    push ax
    
    mov ax, [score]
    cmp ax, [high_score]
    jbe .no_update
    
    mov [high_score], ax

.no_update:
    pop ax
    ret

; =============================================================================
; Limpiar pantalla
; =============================================================================
clear_screen:
    push ax
    push bx
    push cx
    push dx
    
    mov ax, 0600h           ; Scroll up, limpiar ventana
    mov bh, COLOR_BG        ; Atributo de fondo
    xor cx, cx              ; Esquina superior izquierda (0,0)
    mov dx, 184Fh           ; Esquina inferior derecha (24,79)
    int 10h
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Dibujar borde del área de juego
; Borde en: fila 3 (arriba), fila 23 (abajo), columna 1 (izq), columna 78 (der)
; =============================================================================
draw_border:
    push ax
    push bx
    push cx
    push dx
    
    ; Borde superior (fila 3, columnas 1-78)
    mov dh, 3
    mov dl, 1
.top_border:
    cmp dl, 79
    jge .bottom_border
    
    call set_cursor
    mov ah, 09h
    mov al, '#'
    mov bh, 0
    mov bl, COLOR_BORDER
    mov cx, 1
    int 10h
    
    inc dl
    jmp .top_border

.bottom_border:
    ; Borde inferior (fila 23, columnas 1-78)
    mov dh, 23
    mov dl, 1
.bottom_loop:
    cmp dl, 79
    jge .left_border
    
    call set_cursor
    mov ah, 09h
    mov al, '#'
    mov bh, 0
    mov bl, COLOR_BORDER
    mov cx, 1
    int 10h
    
    inc dl
    jmp .bottom_loop

.left_border:
    ; Borde izquierdo (columna 1, filas 3-23)
    mov dh, 3
    mov dl, 1
.left_loop:
    cmp dh, 24
    jge .right_border
    
    call set_cursor
    mov ah, 09h
    mov al, '#'
    mov bh, 0
    mov bl, COLOR_BORDER
    mov cx, 1
    int 10h
    
    inc dh
    jmp .left_loop

.right_border:
    ; Borde derecho (columna 78, filas 3-23)
    mov dh, 3
    mov dl, 78
.right_loop:
    cmp dh, 24
    jge .done
    
    call set_cursor
    mov ah, 09h
    mov al, '#'
    mov bh, 0
    mov bl, COLOR_BORDER
    mov cx, 1
    int 10h
    
    inc dh
    jmp .right_loop

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Posicionar cursor
; Entrada: DH = fila, DL = columna
; =============================================================================
set_cursor:
    push ax
    push bx
    
    mov ah, 02h
    mov bh, 0
    int 10h
    
    pop bx
    pop ax
    ret

; =============================================================================
; Imprimir cadena terminada en null
; Entrada: SI = puntero a cadena, BL = color
; =============================================================================
print_string:
    push ax
    push bx
    push cx
    push si
    
.loop:
    lodsb
    cmp al, 0
    je .done
    
    mov ah, 0Eh
    mov bh, 0
    int 10h
    
    jmp .loop

.done:
    pop si
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Imprimir número (sin ceros a la izquierda)
; Entrada: AX = número a imprimir
; =============================================================================
print_number:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Convertir número a cadena ASCII
    mov di, num_buffer + 5
    mov byte [di], 0        ; Terminador null
    dec di
    
    mov cx, 10              ; Divisor
    mov bx, 0               ; Contador de dígitos

.convert_loop:
    xor dx, dx
    div cx                  ; AX = AX / 10, DX = AX mod 10
    add dl, '0'
    mov [di], dl
    inc bx
    dec di
    
    cmp ax, 0
    jne .convert_loop
    
    ; Ahora BX tiene el número de dígitos
    ; DI apunta un byte antes del primer dígito
    inc di
    
    ; Calcular cuántos espacios necesitamos (5 - número de dígitos)
    mov cx, 5
    sub cx, bx              ; CX = espacios a imprimir
    
.print_spaces:
    cmp cx, 0
    jbe .print_digits       ; Si CX <= 0 (unsigned), no imprimir espacios
    
    mov ah, 0Eh
    mov al, ' '             ; Espacio en lugar de cero a la izquierda
    mov bh, 0
    int 10h
    dec cx
    jmp .print_spaces

.print_digits:
    ; Imprimir los dígitos
    mov ah, 0Eh
    mov bh, 0
.print_loop:
    mov al, [di]
    cmp al, 0
    je .done
    int 10h
    inc di
    jmp .print_loop

.done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Esperar una tecla
; Salida: AL = código ASCII, AH = código de escaneo
; =============================================================================
wait_for_key:
    mov ah, 00h
    int 16h
    ret

; =============================================================================
; Delay del juego
; =============================================================================
game_delay:
    push ax
    push cx
    push dx
    
    ; Usar delay del BIOS (int 15h, ah=86h)
    ; CX:DX = tiempo en microsegundos (valor de 32 bits)
    ; 0x186A0 = 100000 decimal = 100ms
    mov cx, 1               ; Parte alta del valor 0x186A0
    mov dx, 86A0h           ; Parte baja del valor 0x186A0
    mov ah, 86h
    int 15h
    
    pop dx
    pop cx
    pop ax
    ret

; =============================================================================
; Datos del juego
; =============================================================================
section .data

; Mensajes
title_str:          db '=== JUEGO DE LA SERPIENTE ===', 0
instructions1_str:  db 'Usa las flechas para mover', 0
instructions2_str:  db 'Come la comida (*) para crecer', 0
instructions3_str:  db 'Evita los bordes y tu cuerpo', 0
high_score_str:     db 'PUNTUACION MAXIMA: ', 0
press_enter_str:    db 'Presiona ENTER para jugar', 0
score_str:          db 'PUNTOS: ', 0
length_str:         db 'LONGITUD: ', 0
game_over_str:      db '=== GAME OVER ===', 0
victory_str:        db '=== VICTORIA! SERPIENTE COMPLETA ===', 0
final_score_str:    db 'PUNTUACION FINAL: ', 0
press_key_str:      db 'Presiona cualquier tecla para continuar', 0

; =============================================================================
; Variables del juego
; =============================================================================
section .bss

; Estado del juego
game_over_flag:     resb 1
direction:          resb 1
next_direction:     resb 1
snake_length:       resb 1
retry_counter:      resb 1

; Puntuaciones
score:              resw 1
high_score:         resw 1

; Posición de la serpiente (arreglos de coordenadas)
snake_x:            resw MAX_LEN
snake_y:            resw MAX_LEN

; Posición de la comida
food_x:             resw 1
food_y:             resw 1

; Semilla del generador aleatorio
rand_seed:          resw 1

; Buffer para conversión de números
num_buffer:         resb 8
