// gpuinfo: клиент mlkd-фасада amdgpu — mlgpu INFO на /dev/amdgpu.

#include "milin.h"
#include "mlgpu.h"

void milin_main(void) {
    long fd = sys3(SYS_open, (long)"/dev/amdgpu", O_RDWR, 0);
    if (fd < 0) {
        const char *e = "gpuinfo: /dev/amdgpu: недоступен (фасад не в домене?)\n";
        sys3(SYS_write, 2, (long)e, m_strlen(e));
        sys3(SYS_exit, 1, 0, 0);
    }
    u8 op = MLGPU_INFO;
    if (sys3(SYS_write, fd, (long)&op, 1) != 1) {
        const char *e = "gpuinfo: INFO: домен отклонил запрос (-ENODEV при user)\n";
        sys3(SYS_write, 2, (long)e, m_strlen(e));
        sys3(SYS_exit, 2, 0, 0);
    }
    struct mlgpu_info_out o;
    long n = sys3(SYS_read, fd, (long)&o, sizeof(o));
    sys3(SYS_close, fd, 0, 0);
    if (n != (long)sizeof(o) || m_strncmp(o.name, "amdgpu", 7) != 0) {
        const char *e = "gpuinfo: INFO: битый ответ фасада\n";
        sys3(SYS_write, 2, (long)e, m_strlen(e));
        sys3(SYS_exit, 3, 0, 0);
    }
    sys3(SYS_write, 1, (long)"gpuinfo: ", 9);
    sys3(SYS_write, 1, (long)o.name, m_strlen(o.name));
    sys3(SYS_write, 1, (long)" api=", 5);
    print_dec_n(o.api);
    sys3(SYS_write, 1, (long)" mode=", 6);
    print_dec_n(o.mode);
    sys3(SYS_write, 1, (long)" vram=", 6);
    print_dec_n((long)(o.vram_bytes / 1024));
    sys3(SYS_write, 1, (long)"K fences=", 9);
    print_dec_n((long)o.fences);
    sys3(SYS_write, 1, (long)"\n", 1);
    sys3(SYS_exit, 0, 0, 0);
    __builtin_unreachable();
}
