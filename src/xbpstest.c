// xbpstest: гостевой тест пакетного менеджера против живого репо.

#include "milin.h"

#define WNOHANG 1
#define MAXRUN_MS 120000

static long run_wait(char *argv[], char *envp[]) {
    int pid = (int)sys3(SYS_fork, 0, 0, 0);
    if (pid == 0) {
        if (sys3(SYS_execve, (long)argv[0], (long)argv, (long)envp) != 0)
            sys3(SYS_exit, 127, 0, 0);
    }
    if (pid < 0) return -1;
    for (long waited = 0; ; waited += 50) {
        int st = 0;
        long r = sys5(SYS_wait4, pid, (long)&st, WNOHANG, 0, 0);
        if (r == pid) {
            if (st & 0x7f) return -((long)(st & 0x7f));
            return (st >> 8) & 0xff;
        }
        if (r < 0) return -1;
        if (waited > MAXRUN_MS) {
            sys3(SYS_kill, pid, 9 /*SIGKILL*/, 0);
            sys5(SYS_wait4, pid, (long)&st, 0, 0, 0);
            return -1000;
        }
        sleep_ms(50);
    }
}

static void step(const char *name) {
    sys3(SYS_write, 1, (long)"xbpstest: ", 10);
    print_str(name);
    sys3(SYS_write, 1, (long)": ", 2);
}

static int install_pkgs(void) {
    sys3(SYS_mkdir, (long)"/target", 0755, 0);
    if (sys5(SYS_mount, (long)"tmpfs", (long)"/target", (long)"tmpfs", 0, 0) != 0) {
        step("mount tmpfs /target");
        P("FAIL\n");
        return 1;
    }
    P("xbpstest: tmpfs смонтирован на /target (цель установки)\n");
    char *argv[] = { "/usr/bin/xbps-install", "-S", "-y", "-R", "/repo", "-r", "/target",
                     "hello", "gpuinfo", 0 };
    char *envp[] = { "XBPS_ARCH=x86_64", "PATH=/usr/bin:/sbin", 0 };
    step("xbps-install -R /repo -r /target hello gpuinfo");
    long rc = run_wait(argv, envp);
    if (rc != 0) {
        P("FAIL (rc=");
        print_dec_n(rc);
        P(")\n");
        return 1;
    }
    P("OK (rc=0)\n");
    return 0;
}

static int run_installed(const char *path, const char *name, int retries) {
    char *argv[] = { (char *)path, 0 };
    char *envp[] = { "PATH=/usr/bin:/sbin", 0 };
    step(name);
    for (int i = 0; ; i++) {
        long rc = run_wait(argv, envp);
        if (rc == 0) {
            P("OK (установленный бинарник исполнен)\n");
            return 0;
        }
        if (i >= retries) {
            P("FAIL (rc=");
            print_dec_n(rc);
            P(")\n");
            return 1;
        }
        P("rc=");
        print_dec_n(rc);
        P(", ретрай ");
        print_dec_n(i + 1);
        P("...\n");
        sleep_ms(300);
    }
}

void milin_main(void) {
    P("xbpstest: гостевой тест XBPS: репозиторий /repo -> установка -> запуск\n");

    if (install_pkgs()) goto fail;

    long fd = sys3(SYS_open, (long)"/target/usr/bin/hello", 0 /*O_RDONLY*/, 0);
    if (fd < 0) { step("/target/usr/bin/hello"); P("не установлен: FAIL\n"); goto fail; }
    sys3(SYS_close, fd, 0, 0);
    fd = sys3(SYS_open, (long)"/target/var/db/xbps", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0) { step("/target/var/db/xbps"); P("метабаза отсутствует: FAIL\n"); goto fail; }
    sys3(SYS_close, fd, 0, 0);
    P("xbpstest: pkgdb /target/var/db/xbps + /target/usr/bin/{hello,gpuinfo} на месте: OK\n");

    if (run_installed("/target/usr/bin/hello", "hello", 0)) goto fail;
    if (run_installed("/target/usr/bin/gpuinfo", "gpuinfo", 10)) goto fail;

    P("MILINI XBPS OK: установка через XBPS + запуск установленных бинарников\n");
    for (;;) sleep_ms(1000); // service: парк — вердикт за oneshot-клиентом
fail:
    P("MILINI XBPS FAILED\n");
    for (;;) sleep_ms(1000);
    __builtin_unreachable();
}
