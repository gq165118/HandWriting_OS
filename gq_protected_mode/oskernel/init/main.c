//
// Created by ziya on 22-6-23.
//
extern void gq_ctest(void);
extern char var;

void kernel_main(void) {
    int a = 0;

    char* video = (char*)0xb8000;
    *video = 'G';

    gq_ctest();
    *video = var;
}

void c_test(void) {
    int a = 0;

    char* video = (char*)0xb8000;
    *video = 'Z';
}