// hello: проверка, что пакет, установленный XBPS'ом, реально исполняется ядром MiLin.

#include "milin.h"

void milin_main(void) {
    const char *msg = "Hello from MiLini (installed via XBPS)!\n";
    sys3(SYS_write, 1, (long)msg, 40);
    sys3(SYS_exit, 0, 0, 0);
    __builtin_unreachable();
}
