%include "includes/io.inc"

extern getAST
extern freeAST

struc Node
    data: resd 1
    left: resd 1
    right: resd 1
endstruc

section .bss
    root: resd 1

section .data
    node_addresses times 200 dd 0 ; 200 - max operations, as stated by the homework
    node_number dd 0

section .text
global main

string_to_int:
    push ebp
    mov ebp, esp
    
    mov ebx, [ebp + 8] ; get the address
    
    cmp BYTE [ebx], '-'
    jne input_not_negative
    inc ebx ; negative number, skip this character and treat later
    
input_not_negative:
    xor eax, eax
    xor edx, edx
    
byte_by_byte_loop:
    movzx ecx, BYTE [ebx] ; get a single byte
    cmp ecx, 0 ; if NULL, it's end of string, exit
    je end_loop
    
    sub ecx, '0' ; get its corresponding number out of ASCII character
    
    mov edi, 10
    mul edi ; eax * 10
    add eax, ecx
    
    inc ebx ; move to the next byte
    jmp byte_by_byte_loop ; repeat
end_loop:

    mov ebx, [ebp + 8] ; get the address again
    cmp BYTE [ebx], '-' ; the number is negative, get its two complement
    jne result_not_negative
    not eax
    inc eax
    
result_not_negative:
    leave
    ret

do_operation:
    ; returns the result in eax
    push ebp
    mov ebp, esp
    
    push DWORD [ebp + 12] ; address of right operand
    call string_to_int
    add esp, 4
    
    mov ebx, eax ; move the int to ebx
        
    push ebx ; string_to_int will modify ebx

    push DWORD [ebp + 8] ; address of left operand
    call string_to_int
    add esp, 4
    
    pop ebx ; restore
    
    ; int already in eax
    
    mov ecx, [ebp + 16] ; operator code
    
    cmp ecx, 1 ; addition
    jne not_addition
    add eax, ebx
    jmp end_operation
    
not_addition:
    cmp ecx, 2 ; subtraction
    jne not_subtraction
    sub eax, ebx
    jmp end_operation
    
not_subtraction:
    cmp ecx, 3 ; multiplication
    jne not_multiplication
    
    imul ebx
    jmp end_operation
    
not_multiplication:
    cmp ecx, 4 ; division
    jne not_division
    cdq
    idiv ebx
    jmp end_operation
    
not_division:
    ; should not reach here, something went wrong
    PRINT_STRING "No operation found!"
    NEWLINE
    
end_operation:
    leave
    ret

write_result:
    push ebp
    mov ebp, esp
    
    mov ecx, [ebp + 8] ; get the address to write to
    mov eax, [ebp + 12] ; get the number to write
    
    test eax, eax
    jns dividend_not_signed
    mov BYTE [ecx], '-' ; if signed, write minus sign
    inc ecx
    
dividend_not_signed:
    mov ebx, 10 ; to repeatly divide
    
start_div_loop:
    cmp eax, 0
    je start_write_loop ; end this loop

    cdq
    idiv ebx
    
    test edx, edx
    jns remainder_not_signed ; make sure the remainder is positive before pushing
    not edx ; get its two complement
    inc edx
    
remainder_not_signed:
    push edx ; in order to move through the digits in reverse order with pop
    jmp start_div_loop
    
start_write_loop:
    cmp esp, ebp
    je end_write_loop
    
    pop edx ; get the reminder in reverse order

    add edx, '0' ; get the corresponding ASCII code of the digit
    
    mov BYTE [ecx], dl ; write it to the string
    inc ecx
    
    jmp start_write_loop
    
end_write_loop:
    mov BYTE [ecx], 0 ; end the string with NULL character
    
    leave
    ret
    
is_operator:
    ; returns:  0 - if operand
    ;           1 - if '+'
    ;           2 - if '-'
    ;           3 - if '*'
    ;           4 - if '/'
    push ebp
    mov ebp, esp
    
    mov eax, [ebp + 8] ; get the argument
    
    cmp BYTE [eax], '-' ; may be a negative number, or the minus sign
    jne not_minus
    cmp BYTE [eax + 1], 0 ; if it's followed by the NULL character, it's the minus sign
    jne not_minus
    push DWORD 2
    jmp end_is_operator
    
not_minus:
    cmp BYTE [eax], '+'
    jne not_plus
    push DWORD 1
    jmp end_is_operator
    
not_plus:
    cmp BYTE [eax], '*'
    jne not_star
    push DWORD 3
    jmp end_is_operator
    
not_star:
    cmp BYTE [eax], '/'
    jne not_slash
    push DWORD 4
    jmp end_is_operator
    
not_slash:
    ; nothing else means it's an operand
    push DWORD 0
    
end_is_operator:
    pop eax

    leave
    ret

evaluate_addresses:
    cmp DWORD [node_number], 3
    jl end_evaluation ; nothing to do, an operation involves an operator and two operands (total of 3 nodes)
    
    ; search for the following pattern: operand -> operand -> operator (at the end of the array, in reverse order)
    
    mov esi, [node_number]
    dec esi
    
    ; first operand
    push DWORD [node_addresses + esi*4] ; last address
    call is_operator ; returns operator code if true, 0 if operand
    add esp, 4
    
    cmp eax, 0
    jnz end_evaluation ; should NOT be an operator
    
    ; second operand
    push DWORD [node_addresses + esi*4 - 4] ; second to last address
    call is_operator
    add esp, 4
    
    cmp eax, 0
    jnz end_evaluation ; should NOT be an operator
    
    ; the operator
    push DWORD [node_addresses + esi*4 - 8] ; third to last address
    call is_operator ; 0 - if an operator
    add esp, 4
    
    cmp eax, 0
    jz end_evaluation ; should BE an operator
    
    ; if it reached here, we are able to do an operation
    
    push eax ; eax now holds the operator code
    push DWORD [node_addresses + esi*4] ; address of right operand
    push DWORD [node_addresses + esi*4 - 4] ; address of left operand
    call do_operation
    add esp, 12
    
    push eax ; eax now holds the result of do_operation
    push DWORD [node_addresses + esi*4 - 8] ; write at this address as string
    call write_result
    add esp, 8
    
    mov DWORD [node_addresses + esi*4 - 4], 0 ; not needed anymore
    mov DWORD [node_addresses + esi*4], 0
    sub DWORD [node_number], 2 ; we have used these two operands
    
    jmp evaluate_addresses ; do it until it's no longer necessary (will jump to end_evaluation at that moment)

push_nodes:
    push ebp
    mov ebp, esp
    
    ; if null, end recursion
    cmp ebx, 0
    je exit_push_nodes
    
    ; do stuff on this node
    mov edx, [ebx + data] ; get the data
    mov esi, [node_number]
    mov [node_addresses + esi*4], edx ; save address in array
    inc DWORD [node_number] ; another address added
    
    push ebx ; will be modified in evaluate_addresses
    
    jmp evaluate_addresses ; evaluate the array
end_evaluation:
    
    pop ebx ; restore
    
    ; call on left child
    push ebx ; save for future call
    mov ebx, [ebx + left] ; prepare to call on left child
    call push_nodes
    pop ebx ; restore
    
    ; call on right child
    mov ebx, [ebx + right] ; prepare to call on right child
    call push_nodes

exit_push_nodes:
    leave
    ret

main:
    push ebp
    mov ebp, esp
    
    call getAST
    mov [root], eax
        
    ; push the entire tree in pre-order
    ; save the current node in ebx, starting with root
    mov ebx, [root]
    call push_nodes ; no arguments, work on ebx 
    
    ; print the result
    mov ebx, [root]
    mov ebx, [ebx + data]
    PRINT_STRING [ebx]
    
    push dword [root]
    call freeAST
    
    xor eax, eax
    leave
    ret