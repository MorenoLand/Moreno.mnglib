bits 64
default rel

section .text

global mng_is_mng
mng_is_mng:
    test rcx, rcx
    jz .not_mng
    cmp rdx, 8
    jb .not_mng
    mov rax, [rcx]
    mov r10, 0x0A1A0A0D474E4D8A
    cmp rax, r10
    jne .not_mng
    mov eax, 1
    ret
.not_mng:
    xor eax, eax
    ret

global mng_frame_count
mng_frame_count:
    test rcx, rcx
    jz .invalid
    cmp rdx, 8
    jb .invalid
    mov r8, rcx
    mov r9, rdx
    mov rax, [r8]
    mov rdx, 0x0A1A0A0D474E4D8A
    cmp rax, rdx
    jne .invalid
    mov r10, 8
    xor r11d, r11d
    xor ecx, ecx
.next_chunk:
    cmp r10, r9
    jae .complete
    mov rax, r9
    sub rax, r10
    cmp rax, 12
    jb .invalid
    movzx eax, byte [r8 + r10]
    shl rax, 24
    movzx edx, byte [r8 + r10 + 1]
    shl rdx, 16
    or rax, rdx
    movzx edx, byte [r8 + r10 + 2]
    shl rdx, 8
    or rax, rdx
    movzx edx, byte [r8 + r10 + 3]
    or rax, rdx
    mov rdx, rax
    add rdx, 12
    jc .invalid
    mov rax, r9
    sub rax, r10
    cmp rdx, rax
    ja .invalid
    cmp dword [r8 + r10 + 4], 0x5244484D
    jne .not_mhdr
    cmp rdx, 40
    jb .invalid
    jmp .advance
.not_mhdr:
    cmp dword [r8 + r10 + 4], 0x52444849
    jne .not_ihdr
    test ecx, ecx
    jnz .advance
    mov ecx, 1
    jmp .advance
.not_ihdr:
    cmp dword [r8 + r10 + 4], 0x444E4549
    jne .advance
    test ecx, ecx
    jz .advance
    inc r11
    xor ecx, ecx
.advance:
    add r10, rdx
    jmp .next_chunk
.complete:
    test ecx, ecx
    jnz .invalid
    test r11, r11
    jz .invalid
    mov rax, r11
    ret
.invalid:
    xor eax, eax
    ret
