OPTION CASEMAP:NONE

.code

PUBLIC mng_is_mng
mng_is_mng PROC
    test rcx, rcx
    jz mng_is_not_mng
    cmp rdx, 8
    jb mng_is_not_mng
    mov rax, QWORD PTR [rcx]
    mov r10, 0A1A0A0D474E4D8Ah
    cmp rax, r10
    jne mng_is_not_mng
    mov eax, 1
    ret
mng_is_not_mng:
    xor eax, eax
    ret
mng_is_mng ENDP

PUBLIC mng_frame_count
mng_frame_count PROC
    test rcx, rcx
    jz mng_frame_invalid
    cmp rdx, 8
    jb mng_frame_invalid
    mov r8, rcx
    mov r9, rdx
    mov rax, QWORD PTR [r8]
    mov rdx, 0A1A0A0D474E4D8Ah
    cmp rax, rdx
    jne mng_frame_invalid
    mov r10, 8
    xor r11d, r11d
    xor ecx, ecx
mng_frame_next_chunk:
    cmp r10, r9
    jae mng_frame_complete
    mov rax, r9
    sub rax, r10
    cmp rax, 12
    jb mng_frame_invalid
    movzx eax, BYTE PTR [r8+r10]
    shl rax, 24
    movzx edx, BYTE PTR [r8+r10+1]
    shl rdx, 16
    or rax, rdx
    movzx edx, BYTE PTR [r8+r10+2]
    shl rdx, 8
    or rax, rdx
    movzx edx, BYTE PTR [r8+r10+3]
    or rax, rdx
    mov rdx, rax
    add rdx, 12
    jc mng_frame_invalid
    mov rax, r9
    sub rax, r10
    cmp rdx, rax
    ja mng_frame_invalid
    cmp DWORD PTR [r8+r10+4], 5244484Dh
    jne mng_frame_not_mhdr
    cmp rdx, 40
    jb mng_frame_invalid
    jmp mng_frame_advance
mng_frame_not_mhdr:
    cmp DWORD PTR [r8+r10+4], 52444849h
    jne mng_frame_not_ihdr
    test ecx, ecx
    jnz mng_frame_advance
    mov ecx, 1
    jmp mng_frame_advance
mng_frame_not_ihdr:
    cmp DWORD PTR [r8+r10+4], 444E4549h
    jne mng_frame_advance
    test ecx, ecx
    jz mng_frame_advance
    inc r11
    xor ecx, ecx
mng_frame_advance:
    add r10, rdx
    jmp mng_frame_next_chunk
mng_frame_complete:
    test ecx, ecx
    jnz mng_frame_invalid
    test r11, r11
    jz mng_frame_invalid
    mov rax, r11
    ret
mng_frame_invalid:
    xor eax, eax
    ret
mng_frame_count ENDP

END
