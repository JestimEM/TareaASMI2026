.MODEL SMALL
.STACK 100h

; ===== ESTRUCTURA DE CUENTA =====
; Cada cuenta ocupa:
; - Número: 2 bytes (WORD)
; - Nombre: 21 bytes (20 + terminador $)
; - Saldo: 4 bytes (DWORD para 4 decimales)
; - Estado: 1 byte (0=inactiva, 1=activa)
; Total por cuenta: 28 bytes

MAX_CUENTAS EQU 10
TAM_CUENTA EQU 28

.DATA
    ; Arreglo de cuentas
    cuentas DB MAX_CUENTAS * TAM_CUENTA DUP(?)
    
    ; Contador de cuentas registradas
    num_cuentas DW 0
    
    ; Variables auxiliares
    buffer_nombre DB 21 DUP('$')
    buffer_num DB 6 DUP('$')
    buffer_monto DB 11 DUP('$')  ; Para números hasta 999999.9999
    
    ; Mensajes del menú
    menu_msg DB 13,10,'=== BANCO BankTec ===',13,10
            DB '1. Crear cuenta',13,10
            DB '2. Depositar',13,10
            DB '3. Retirar',13,10
            DB '4. Consultar saldo',13,10
            DB '5. Reporte general',13,10
            DB '6. Desactivar cuenta',13,10
            DB '7. Salir',13,10
            DB 'Opcion: $'
    
    msg_num_cuenta DB 'Numero de cuenta: $'
    msg_nombre DB 'Nombre del titular: $'
    msg_saldo_inicial DB 'Saldo inicial (0-999999.9999): $'
    msg_monto DB 'Monto: $'
    msg_cuenta_no_existe DB 'Cuenta no existe$'
    msg_cuenta_inactiva DB 'Cuenta inactiva$'
    msg_fondos_insuf DB 'Fondos insuficientes$'
    msg_saldo_actual DB 'Saldo actual: $'
    msg_activas DB 'Cuentas activas: $'
    msg_inactivas DB 'Cuentas inactivas: $'
    msg_saldo_total DB 'Saldo total del banco: $'
    msg_mayor_saldo DB 'Cuenta con mayor saldo: $'
    msg_menor_saldo DB 'Cuenta con menor saldo: $'
    
    saldo_total DD 0
    mayor_saldo DW 0
    menor_saldo DW 0
    pos_mayor DW 0
    pos_menor DW 0
    
.CODE

; ============================================
; PROC CrearCuenta
; Crea una nueva cuenta bancaria
; ============================================
CrearCuenta PROC
    push ax bx cx dx si di
    
    ; Verificar si hay espacio
    mov ax, num_cuentas
    cmp ax, MAX_CUENTAS
    jae fin_crear_cuenta  ; No hay espacio
    
    ; Calcular posición en el arreglo
    mov ax, TAM_CUENTA
    mul num_cuentas
    mov si, ax  ; SI = offset de la nueva cuenta
    
    ; ===== Ingresar número de cuenta =====
    mov dx, offset msg_num_cuenta
    mov ah, 9
    int 21h
    
    ; Leer número como string
    mov dx, offset buffer_num
    mov ah, 0Ah
    int 21h
    
    ; Convertir a número
    call StringToWord
    ; Validar que no exista
    call BuscarCuentaPorNumero
    cmp ax, 0FFFFh  ; Si encontró cuenta
    je continuar_crear
    jmp fin_crear_cuenta  ; Ya existe
    
continuar_crear:
    ; Guardar número
    mov [cuentas + si], bx
    
    ; ===== Ingresar nombre =====
    mov dx, offset msg_nombre
    mov ah, 9
    int 21h
    
    mov dx, offset buffer_nombre
    mov ah, 0Ah
    int 21h
    
    ; Guardar nombre
    push si
    add si, 2  ; Saltar número
    lea di, [cuentas + si]
    lea si, buffer_nombre + 2
    mov cx, 20
    rep movsb
    pop si
    
    ; ===== Ingresar saldo inicial =====
    mov dx, offset msg_saldo_inicial
    mov ah, 9
    int 21h
    
    call LeerMonto
    jc fin_crear_cuenta  ; Error o negativo
    
    ; Guardar saldo (convertir a centésimas)
    call ConvertirADecimal
    push si
    add si, 23  ; Offset del saldo (2 + 21)
    mov [cuentas + si], ax
    pop si
    
    ; Estado = Activa (1)
    push si
    add si, 27  ; Offset del estado (2+21+4)
    mov byte ptr [cuentas + si], 1
    pop si
    
    ; Incrementar contador
    inc num_cuentas
    
    mov dx, offset msg_cuenta_creada
    mov ah, 9
    int 21h
    
fin_crear_cuenta:
    pop di si dx cx bx ax
    ret
CrearCuenta ENDP

; ============================================
; PROC BuscarCuentaPorNumero
; Entrada: BX = número a buscar
; Salida: AX = posición (0-9) o FFFFh si no existe
; ============================================
BuscarCuentaPorNumero PROC
    push cx dx si
    mov cx, num_cuentas
    mov ax, 0FFFFh  ; Valor por defecto (no encontrado)
    
    cmp cx, 0
    je fin_buscar
    
    xor si, si
buscar_loop:
    cmp [cuentas + si], bx
    je encontrado
    add si, TAM_CUENTA
    loop buscar_loop
    jmp fin_buscar
    
encontrado:
    mov ax, si  ; Retornar posición
    
fin_buscar:
    pop si dx cx
    ret
BuscarCuentaPorNumero ENDP

; ============================================
; PROC Depositar
; ============================================
Depositar PROC
    push ax bx cx dx si
    
    ; Pedir número de cuenta
    mov dx, offset msg_num_cuenta
    mov ah, 9
    int 21h
    
    mov dx, offset buffer_num
    mov ah, 0Ah
    int 21h
    
    call StringToWord
    call BuscarCuentaPorNumero
    cmp ax, 0FFFFh
    je cuenta_no_existe_dep
    
    ; Verificar estado
    mov si, ax
    push si
    add si, 27  ; Estado
    cmp byte ptr [cuentas + si], 1
    pop si
    jne cuenta_inactiva_dep
    
    ; Pedir monto
    mov dx, offset msg_monto
    mov ah, 9
    int 21h
    
    call LeerMonto
    jc error_monto_dep
    
    ; Sumar al saldo
    push si
    add si, 23  ; Offset saldo
    add [cuentas + si], ax
    pop si
    
    jmp fin_depositar
    
cuenta_no_existe_dep:
    mov dx, offset msg_cuenta_no_existe
    mov ah, 9
    int 21h
    jmp fin_depositar
    
cuenta_inactiva_dep:
    mov dx, offset msg_cuenta_inactiva
    mov ah, 9
    int 21h
    
error_monto_dep:
fin_depositar:
    pop si dx cx bx ax
    ret
Depositar ENDP

; ============================================
; PROC Retirar
; ============================================
Retirar PROC
    push ax bx cx dx si
    
    ; Pedir número de cuenta
    mov dx, offset msg_num_cuenta
    mov ah, 9
    int 21h
    
    mov dx, offset buffer_num
    mov ah, 0Ah
    int 21h
    
    call StringToWord
    call BuscarCuentaPorNumero
    cmp ax, 0FFFFh
    je cuenta_no_existe_ret
    
    ; Verificar estado
    mov si, ax
    push si
    add si, 27  ; Estado
    cmp byte ptr [cuentas + si], 1
    pop si
    jne cuenta_inactiva_ret
    
    ; Pedir monto
    mov dx, offset msg_monto
    mov ah, 9
    int 21h
    
    call LeerMonto
    jc error_monto_ret
    
    ; Verificar fondos suficientes
    push si
    add si, 23  ; Offset saldo
    cmp [cuentas + si], ax
    pop si
    jb fondos_insuficientes
    
    ; Restar del saldo
    push si
    add si, 23
    sub [cuentas + si], ax
    pop si
    
    jmp fin_retirar
    
cuenta_no_existe_ret:
    mov dx, offset msg_cuenta_no_existe
    mov ah, 9
    int 21h
    jmp fin_retirar
    
cuenta_inactiva_ret:
    mov dx, offset msg_cuenta_inactiva
    mov ah, 9
    int 21h
    jmp fin_retirar
    
fondos_insuficientes:
    mov dx, offset msg_fondos_insuf
    mov ah, 9
    int 21h
    
error_monto_ret:
fin_retirar:
    pop si dx cx bx ax
    ret
Retirar ENDP

; ============================================
; PROC EncontrarMayorSaldo (recursiva)
; ============================================
EncontrarMayorSaldo PROC
    ; Caso base: si solo queda una cuenta
    cmp cx, 1
    jne continuar_mayor
    
    ; Guardar posición actual
    mov pos_mayor, si
    push si
    add si, 23
    mov ax, [cuentas + si]
    mov mayor_saldo, ax
    pop si
    ret
    
continuar_mayor:
    ; Guardar estado
    push ax bx cx dx
    
    ; Llamada recursiva para el resto
    dec cx
    add si, TAM_CUENTA
    call EncontrarMayorSaldo
    sub si, TAM_CUENTA
    inc cx
    
    ; Comparar con cuenta actual
    push si
    add si, 23
    mov ax, [cuentas + si]
    pop si
    
    cmp ax, mayor_saldo
    jbe no_actualizar_mayor
    
    ; Actualizar mayor
    mov mayor_saldo, ax
    mov pos_mayor, si
    
no_actualizar_mayor:
    pop dx cx bx ax
    ret
EncontrarMayorSaldo ENDP

; ============================================
; PROC EncontrarMenorSaldo (recursiva)
; ============================================
EncontrarMenorSaldo PROC
    ; Similar a mayor pero con comparación inversa
    cmp cx, 1
    jne continuar_menor
    
    mov pos_menor, si
    push si
    add si, 23
    mov ax, [cuentas + si]
    mov menor_saldo, ax
    pop si
    ret
    
continuar_menor:
    push ax bx cx dx
    
    dec cx
    add si, TAM_CUENTA
    call EncontrarMenorSaldo
    sub si, TAM_CUENTA
    inc cx
    
    push si
    add si, 23
    mov ax, [cuentas + si]
    pop si
    
    cmp ax, menor_saldo
    jae no_actualizar_menor
    
    mov menor_saldo, ax
    mov pos_menor, si
    
no_actualizar_menor:
    pop dx cx bx ax
    ret
EncontrarMenorSaldo ENDP

; ============================================
; PROC MostrarReporte
; ============================================
MostrarReporte PROC
    push ax bx cx dx si
    
    ; Inicializar contadores
    xor bx, bx  ; Activas
    xor cx, cx  ; Inactivas
    mov dword ptr [saldo_total], 0
    
    ; Recorrer todas las cuentas
    xor si, si
    mov dx, num_cuentas
    cmp dx, 0
    je fin_reporte
    
reporte_loop:
    push dx
    
    ; Verificar estado
    push si
    add si, 27
    cmp byte ptr [cuentas + si], 1
    pop si
    je es_activa
    
    ; Inactiva
    inc cx
    jmp sumar_saldo
    
es_activa:
    inc bx
    
sumar_saldo:
    ; Sumar al total
    push si
    add si, 23
    mov ax, [cuentas + si]
    add word ptr [saldo_total], ax
    pop si
    
    add si, TAM_CUENTA
    pop dx
    dec dx
    jnz reporte_loop
    
    ; Encontrar mayor y menor saldo
    mov si, 0
    mov cx, num_cuentas
    call EncontrarMayorSaldo
    
    mov si, 0
    mov cx, num_cuentas
    call EncontrarMenorSaldo
    
    ; Mostrar resultados
    call MostrarActivas
    call MostrarInactivas
    call MostrarSaldoTotal
    call MostrarMayorSaldo
    call MostrarMenorSaldo
    
fin_reporte:
    pop si dx cx bx ax
    ret
MostrarReporte ENDP

; ============================================
; PROC StringToWord
; Convierte string a número en BX
; ============================================
StringToWord PROC
    push ax cx si
    
    xor bx, bx
    lea si, buffer_num + 2
    
convertir_loop:
    mov al, [si]
    cmp al, 0Dh  ; Enter
    je fin_conversion
    cmp al, 0
    je fin_conversion
    
    sub al, '0'
    mov ah, 0
    
    push ax
    mov ax, bx
    mov cx, 10
    mul cx
    mov bx, ax
    pop ax
    
    add bx, ax
    inc si
    jmp convertir_loop
    
fin_conversion:
    pop si cx ax
    ret
StringToWord ENDP

; ============================================
; PROC WordToString
; Convierte BX a string en buffer
; ============================================
WordToString PROC
    push ax bx cx dx
    
    mov cx, 10
    mov di, offset buffer_num + 5
    mov byte ptr [di + 1], '$'
    
convertir_loop2:
    xor dx, dx
    mov ax, bx
    div cx
    mov bx, ax
    add dl, '0'
    mov [di], dl
    dec di
    cmp bx, 0
    jne convertir_loop2
    
    inc di
    mov dx, di
    mov ah, 9
    int 21h
    
    pop dx cx bx ax
    ret
WordToString ENDP

; ============================================
; PROC LeerMonto
; Lee monto y valida que sea positivo
; ============================================
LeerMonto PROC
    push bx cx dx
    
    mov dx, offset buffer_monto
    mov ah, 0Ah
    int 21h
    
    call ValidarMonto
    jc monto_invalido
    
    ; Convertir a número (centésimas)
    call StringToWord
    ; Aquí se manejaría la conversión de decimales
    
    clc  ; Clear carry (éxito)
    jmp fin_leer_monto
    
monto_invalido:
    stc  ; Set carry (error)
    
fin_leer_monto:
    pop dx cx bx
    ret
LeerMonto ENDP

; ============================================
; PROC ValidarMonto
; Verifica que el monto sea número válido
; ============================================
ValidarMonto PROC
    push si
    
    lea si, buffer_monto + 2
    cmp byte ptr [si], '-'  ; Negativo?
    je monto_negativo
    
validar_loop:
    mov al, [si]
    cmp al, 0Dh
    je monto_valido
    cmp al, '.'
    je validar_decimal
    cmp al, '0'
    jb monto_negativo
    cmp al, '9'
    ja monto_negativo
    inc si
    jmp validar_loop
    
validar_decimal:
    ; Validar parte decimal
    inc si
    jmp validar_loop
    
monto_valido:
    clc
    jmp fin_validar
    
monto_negativo:
    stc
    
fin_validar:
    pop si
    ret
ValidarMonto ENDP

; ============================================
; PROC MenuPrincipal
; ============================================
MenuPrincipal PROC
    mov ax, @DATA
    mov ds, ax
    
menu_loop:
    ; Limpiar pantalla
    mov ah, 0
    mov al, 3
    int 10h
    
    ; Mostrar menú
    mov dx, offset menu_msg
    mov ah, 9
    int 21h
    
    ; Leer opción
    mov ah, 1
    int 21h
    
    cmp al, '1'
    je opcion_crear
    cmp al, '2'
    je opcion_depositar
    cmp al, '3'
    je opcion_retirar
    cmp al, '4'
    je opcion_consultar
    cmp al, '5'
    je opcion_reporte
    cmp al, '6'
    je opcion_desactivar
    cmp al, '7'
    je opcion_salir
    jmp menu_loop
    
opcion_crear:
    call CrearCuenta
    jmp menu_loop
    
opcion_depositar:
    call Depositar
    jmp menu_loop
    
opcion_retirar:
    call Retirar
    jmp menu_loop
    
opcion_consultar:
    call ConsultarSaldo
    jmp menu_loop
    
opcion_reporte:
    call MostrarReporte
    jmp menu_loop
    
opcion_desactivar:
    call DesactivarCuenta
    jmp menu_loop
    
opcion_salir:
    mov ax, 4C00h
    int 21h
    
MenuPrincipal ENDP

END MenuPrincipal