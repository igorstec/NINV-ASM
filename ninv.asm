; ninv.asm

; declaration from libc
extern malloc
extern free

; Make ninv avaible.
global ninv

section .text
; void ninv(uint64_t *y, uint64_t const *x, uint64_t n)
; rdi = pointer into result 
; rsi = pointer into value
; rdx = num of the bites

; The function calculates y for said x > 1 so that: 𝑥𝑦≤2𝑛<𝑥(𝑦+1).

; usage of callee-safe registers:
; r12 = pointer to R
; r13 = pointer to y
; r14 = pointer to x
; r15 = block_count (n / 64) 
; rbx = num of the bites (n)
ninv:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r13, rdi                ; set y pointer
    mov r14, rsi                ; set x pointer
    mov rbx, rdx                ; set n 
    shr rdx, 6                  ; n / 64 (block_count)
    mov r15, rdx                ; set block_count

; INITIALIZE y TO 0
    xor rax, rax                ; set rax = 0
    mov rcx, r15                ; set counter
    cld                         ; clear direction flag (increment mode)
    rep stosq     
    
; ALLOCATE MEMORY FOR R
; r12 = pointer to R 

; MALLOC verison
    mov rdi, r15                ; rdi = n/64
    inc rdi                     ; rdi = n/64 + 1
    shl rdi, 3                  ; rdi = (n/64 + 1) * 8
    call malloc wrt ..plt       ; allocate memory for R
    test rax, rax               ; check if allocation was successful
    jz .end_cleanup             ; if not, return
    mov r12, rax                ; save pointer to allocated array in r12
    mov rdi, r12                ; set rdi = R pointer
    xor rax, rax                ; set rax = 0
    mov rcx, r15                ; set counter
    cld                         ; clear direction flag (increment mode)
    rep stosq                   ; set the R = 0 / r12 = R

; INITIALIZE R TO 2^{n}
    mov qword [r12 + r15*8], 1  ; set R[block_count] = 1

; BIT SCAN LOOP - find most significant bit in x
; r11 = block_count of x
; r10 = bit index offset of x
    mov rdx, r15                            ; set rdx = block_count
.bit_scan:
    dec rdx
    mov rax, [r14 + rdx * 8]
    bsr r10, rax                            ; find most significant bit in x
    jz .bit_scan                            ; if zero, continue
    mov r8, rbx                             ; r8 = n
    sub r8, r10                             ; r8 = n - number of most significant bit in last block in x  
    mov r10, rdx                            ; r10 = block_count of whole blocks x
    shl r10, 6                              ; r10 = block_count * 64
    sub r8, r10                             ; r8 = bit_index to set

    lea r10, [rdx+1]                        ; j = block_count 
    inc r15                                 ; block_count for R (previously it was for x)

; MAIN LOOP
; rbx = n (number of bits)
; r8 = bit_index to set
; rcx = bit offset to set
; r10 = block_count of x
; r12 = pointer to R
; r13 = y (pointer to y)
; r14 = x (pointer to x)
; rdx = bit block to set

; freely used:
; rax, r9, rsi, rdi, r11, r15
.main_loop:
    mov r11, r10                    ; j = block_count
    test r8, r8
    js .end

    mov rcx, r8
    and rcx, 63                     ; rcx = bit_index % 64
    mov rdx, r8
    shr rdx, 6                      ; rdx = bit_index / 64

.compare:
; COMPARE LOOP
; rax = x[j]    (first)
; r9 = x[j - 1](second)
; rsi - unused
; rdi = j + block_move
; r11 = j (block_count -> 0)
; r15 = max_index

    mov r9, 0                       ; set second = 0 

.compare_calculate_element:
    mov rax, r9                     ; first = second

    cmp r11, 0                      ; check j == 0
    je .compare_no_prev             ; if j == 0 -> compare_no_prev (there is no previous element)

    mov r9, [r14 + r11 * 8-8]       ; second = x[j - 1]
    shld rax, r9, cl                ; calculate offset for two elems
    jmp .compare_X_and_R        

.compare_no_prev:
    shl rax, cl                     ; calculate offset for single elem

.compare_X_and_R:
    lea rdi, [r11 + rdx]            ; rdi = j + block_move = block move of R
    cmp rdi, r15                    ; if (j + block_move == max_index) -> skip compare_check
    je .compare_decision
    cmp qword[r12 + rdi*8], rax     ; compare R[j + block_move], new_block of x
.compare_decision:
    jc .main_loop_exit              ; if R smaller we have to dec r8 and try again in the main loop
    ja .set_and_subtract            ; if R bigger we can start subtracting
    ;block were equal -> continue
    cmp r11, 0                
    je .last_set_and_end            ; if j == 0 end loop and set bit
    dec r11                         ; else j-- and continue loop

    jmp .compare_calculate_element

.last_set_and_end:
    bts qword [r13 + rdx*8], rcx
.end:
    mov     rdi, r12                ; free R
    call    free wrt ..plt
.end_cleanup:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret


.set_and_subtract:
; sets the the 2^{r8} in y
; subtracts x * 2^{r8} from R

.set:
    bts qword [r13 + rdx*8], rcx    ; set the bit in y

.subtract:
; SUBSTRACT LOOP
; rax = x[j]    (first)
; r9 = x[j - 1](second)
; rsi = temporary first
; rdi = j + block_move
; r11 = j (0 -> block_count)
; r15 = max_index

    push r8
    xor rax, rax                    ; first = 0
    xor r11, r11                    ; j = 0
    xor r8, r8                      ; clear r8B for carry flag
    clc                             ; clear carry for subtraction

.subtract_check_first_second:
    mov r9, rax                     ; second = first 
    xor rax, rax                    ; first = 0

    cmp r11, r10                    ; check j == block_count
    jae .subtract_calculate_element ; if j >= blocks of x -> subtract_calculate_element (there is no next element or its 0)
    
    mov rax, [r14 + r11 * 8]        ; first = x[j]
.subtract_calculate_element:
    mov rsi, rax                    ; temporary first
    shld rsi, r9, cl                ; calculate offset for two elems
.subtract_X_and_R:
    lea rdi, [r11 + rdx]            ; rdi = j +block_move
    cmp rdi, r15                    ; if (j + block_move == max_index) -> skip subtract
    je .subtract_decision
    bt r8, 0                        ; load carry flag from r8B
    sbb qword[r12 + rdi*8], rsi     ; subtract R[j + block_move], new_block of x
    setc r8B                        ; save carry flag in r8B

.subtract_decision:
    inc r11                         ; j++
    cmp r11, r15                    ; check j == block_count
    jl .subtract_check_first_second ; if not, continue loop
    pop r8

.main_loop_exit:
    dec r8                          ; bit_index--
    jmp .main_loop