[SECTION .text]
[BITS 32]
extern kernel_main
extern c_test

global var
var db 'Q'

global _start

_start:
    call kernel_main

    jmp $

;void gq_ctest(void)
global gq_ctest
gq_ctest:
    call c_test

    ret