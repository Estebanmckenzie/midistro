/*
 * primes_ipc.c  -  Tema 5 (Concurrencia e IPC)  -  proyecto midistro
 *
 * PROBLEMA QUE RESUELVE
 *   Contar cuantos numeros primos hay en [2, LIMITE] repartiendo el trabajo
 *   entre varios procesos (esquema productor / consumidores).
 *
 * ARQUITECTURA
 *
 *   supervisor (padre)
 *      |-- fork --> PRODUCTOR   : corta [2, LIMITE] en trozos y los escribe en el PIPE
 *      |-- fork --> TRABAJADOR 0..N-1 (consumidores):
 *                    leen un trozo del PIPE, cuentan primos y suman su resultado
 *                    en la MEMORIA COMPARTIDA protegida por un MUTEX
 *
 * MECANISMOS DE IPC (se piden al menos dos)
 *   1. pipe()                 productor -> trabajadores (datos)
 *   2. memoria compartida     mmap(MAP_SHARED|MAP_ANONYMOUS): contadores globales
 *   3. senales                SIGCHLD (hijo termino), SIGTERM/SIGINT (apagado ordenado)
 *
 * SINCRONIZACION EXPLICITA
 *   - Mutex pthread con PTHREAD_PROCESS_SHARED (y ROBUST) guardado dentro de la
 *     memoria compartida: protege la seccion critica "leer-sumar-escribir".
 *   - El pipe sincroniza solo: read() bloquea si esta vacio, write() bloquea si
 *     esta lleno. Cada trozo ocupa 16 bytes (< PIPE_BUF) => cada write() es
 *     atomico y dos trabajadores nunca reciben "medio trozo".
 *   - --no-lock desactiva el mutex a proposito para MOSTRAR la condicion de
 *     carrera (actualizaciones perdidas).
 *
 * ZOMBIES
 *   El handler de SIGCHLD llama waitpid(-1, WNOHANG) en bucle y recoge a todos
 *   los hijos. --no-reap lo desactiva para mostrar los zombies que aparecen sin el.
 *
 * COMPILAR:  gcc -O2 -Wall -Wextra -pthread -o primes_ipc primes_ipc.c
 * USO:       ./primes_ipc [-n LIMITE] [-w TRABAJADORES] [-c TAM_TROZO]
 *                         [-s MS_POR_TROZO] [--no-lock] [--no-reap] [-v]
 *
 * Referencias: man 7 pipe, man 7 signal, man 2 waitpid, man 3 pthread_mutexattr_setpshared,
 *              man 2 mmap, man 7 signal-safety.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <getopt.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define MAXW 16

/* Un "trozo" de trabajo. 16 bytes <= PIPE_BUF (4096): write() atomico. */
typedef struct { long lo, hi; } job_t;

/* Todo lo que viaja por memoria compartida. */
typedef struct {
    pthread_mutex_t lock;
    long total_primes;          /* resultado global                  */
    long jobs_done;             /* trozos terminados (para verificar) */
    long per_worker[MAXW];      /* trozos por trabajador (cada uno escribe SOLO el suyo) */
} shared_t;

typedef struct {
    pid_t pid;
    const char *role;
    int idx;
    volatile sig_atomic_t alive;
    volatile int status;        /* status de waitpid, lo llena el handler */
} kid_t;

static shared_t *sh;
static int use_lock = 1;
static kid_t kids[MAXW + 1];
static int nkids = 0;
static volatile sig_atomic_t live_children = 0;
static volatile sig_atomic_t got_term = 0;
static volatile sig_atomic_t term_signo = 0;

/* ---------- utilidades ---------- */
static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static void die(const char *msg) { perror(msg); exit(2); }

static long count_primes(long lo, long hi) {
    long cnt = 0;
    for (long n = lo; n <= hi; n++) {
        if (n < 2) continue;
        if (n % 2 == 0) { if (n == 2) cnt++; continue; }
        int prime = 1;
        for (long d = 3; d * d <= n; d += 2)
            if (n % d == 0) { prime = 0; break; }
        cnt += prime;
    }
    return cnt;
}

/* ---------- seccion critica ---------- */
static void account(int w, long cnt) {
    volatile long *total = &sh->total_primes;
    volatile long *jobs  = &sh->jobs_done;

    if (use_lock) {
        int r = pthread_mutex_lock(&sh->lock);
        if (r == EOWNERDEAD) pthread_mutex_consistent(&sh->lock); /* un hermano murio con el lock */
    }

    /* leer -> modificar -> escribir. Sin mutex, otro proceso puede intercalarse
     * entre la lectura y la escritura y su suma se pierde. sched_yield() ensancha
     * esa ventana para que la carrera sea facil de reproducir (solo en --no-lock). */
    long t = *total;
    if (!use_lock) sched_yield();
    *total = t + cnt;

    long j = *jobs;
    if (!use_lock) sched_yield();
    *jobs = j + 1;

    sh->per_worker[w]++;        /* slot propio: no hay carrera */

    if (use_lock) pthread_mutex_unlock(&sh->lock);
}

/* ---------- senales (solo funciones async-signal-safe) ---------- */
static void on_sigchld(int sig) {
    (void)sig;
    int saved = errno;
    int st;
    pid_t p;
    while ((p = waitpid(-1, &st, WNOHANG)) > 0) {   /* recoge TODOS los hijos terminados */
        for (int i = 0; i < nkids; i++)
            if (kids[i].pid == p) { kids[i].alive = 0; kids[i].status = st; }
        live_children--;
    }
    errno = saved;
}

static void on_sigterm(int sig) {
    got_term = 1;
    term_signo = sig;
}

/* ---------- procesos hijos ---------- */
static void run_producer(int wfd, long limit, long chunk) {
    for (long lo = 2; lo <= limit; lo += chunk) {
        job_t j = { lo, (lo + chunk - 1 > limit) ? limit : lo + chunk - 1 };
        ssize_t n;
        do { n = write(wfd, &j, sizeof j); } while (n < 0 && errno == EINTR);
        if (n != (ssize_t)sizeof j) die("productor: write");
    }
    close(wfd);                 /* cierra el extremo de escritura => los lectores veran EOF */
    _exit(0);
}

static void run_worker(int rfd, int idx, int slow_ms) {
    for (;;) {
        job_t j;
        ssize_t n;
        do { n = read(rfd, &j, sizeof j); } while (n < 0 && errno == EINTR);
        if (n == 0) break;                          /* EOF: no quedan escritores */
        if (n != (ssize_t)sizeof j) { perror("trabajador: read"); _exit(2); }
        long c = count_primes(j.lo, j.hi);
        if (slow_ms > 0) usleep((useconds_t)slow_ms * 1000);
        account(idx, c);
    }
    _exit(0);
}

static void describe(const kid_t *k, char *buf, size_t sz) {
    int st = k->status;
    if (WIFEXITED(st))        snprintf(buf, sz, "salio con codigo %d", WEXITSTATUS(st));
    else if (WIFSIGNALED(st)) snprintf(buf, sz, "murio por senal %d (%s)", WTERMSIG(st), strsignal(WTERMSIG(st)));
    else                      snprintf(buf, sz, "estado %d", st);
}

int main(int argc, char **argv) {
    long limit = 2000000, chunk = 1000;
    int workers = 3, slow_ms = 0, verify = 0, no_reap = 0;

    static const struct option opts[] = {
        {"no-lock", no_argument, 0, 'L'}, {"no-reap", no_argument, 0, 'R'},
        {"limit", required_argument, 0, 'n'}, {"workers", required_argument, 0, 'w'},
        {"chunk", required_argument, 0, 'c'}, {"slow", required_argument, 0, 's'},
        {"verify", no_argument, 0, 'v'}, {"help", no_argument, 0, 'h'}, {0, 0, 0, 0}};
    int o;
    while ((o = getopt_long(argc, argv, "n:w:c:s:vh", opts, NULL)) != -1) {
        switch (o) {
        case 'n': limit = atol(optarg); break;
        case 'w': workers = atoi(optarg); break;
        case 'c': chunk = atol(optarg); break;
        case 's': slow_ms = atoi(optarg); break;
        case 'v': verify = 1; break;
        case 'L': use_lock = 0; break;
        case 'R': no_reap = 1; break;
        default:
            fprintf(stderr, "uso: %s [-n LIMITE] [-w TRABAJADORES<=%d] [-c TROZO] [-s MS] [--no-lock] [--no-reap] [-v]\n",
                    argv[0], MAXW);
            return o == 'h' ? 0 : 1;
        }
    }
    if (workers < 1 || workers > MAXW || chunk < 1 || limit < 2) { fprintf(stderr, "argumentos invalidos\n"); return 1; }
    setvbuf(stdout, NULL, _IOLBF, 0);

    /* 1) Memoria compartida: sobrevive al fork y la ven todos los hijos. */
    sh = mmap(NULL, sizeof *sh, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (sh == MAP_FAILED) die("mmap");
    memset(sh, 0, sizeof *sh);

    /* 2) Mutex compartido entre PROCESOS (por defecto un mutex solo vale entre hilos). */
    pthread_mutexattr_t ma;
    pthread_mutexattr_init(&ma);
    pthread_mutexattr_setpshared(&ma, PTHREAD_PROCESS_SHARED);
    pthread_mutexattr_setrobust(&ma, PTHREAD_MUTEX_ROBUST);
    pthread_mutex_init(&sh->lock, &ma);

    /* 3) Pipe: fds[0] lectura, fds[1] escritura. */
    int fds[2];
    if (pipe(fds) < 0) die("pipe");

    /* 4) Senales. Se bloquean ANTES del fork para que no se pierda ninguna entre
     *    "crear hijo" y "esperar"; sigsuspend() las desbloquea de forma atomica. */
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sigemptyset(&sa.sa_mask);
    sa.sa_handler = on_sigterm;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    if (!no_reap) {
        sa.sa_handler = on_sigchld;
        sa.sa_flags = SA_NOCLDSTOP;
        sigaction(SIGCHLD, &sa, NULL);
    }
    sigset_t block, orig;
    sigemptyset(&block);
    sigaddset(&block, SIGCHLD); sigaddset(&block, SIGTERM); sigaddset(&block, SIGINT);
    sigprocmask(SIG_BLOCK, &block, &orig);

    double t0 = now();
    printf("[supervisor pid=%d] limite=%ld trabajadores=%d trozo=%ld mutex=%s reap=%s\n",
           getpid(), limit, workers, chunk, use_lock ? "SI" : "NO (carrera a proposito)",
           no_reap ? "NO (zombies a proposito)" : "SI");

    live_children = 1 + workers;

    /* 5) Productor. */
    pid_t p = fork();
    if (p < 0) die("fork");
    if (p == 0) {
        sigprocmask(SIG_SETMASK, &orig, NULL);
        signal(SIGTERM, SIG_DFL); signal(SIGINT, SIG_DFL); signal(SIGCHLD, SIG_DFL);
        close(fds[0]);                          /* el productor no lee */
        run_producer(fds[1], limit, chunk);
    }
    kids[nkids++] = (kid_t){ p, "productor", -1, 1, 0 };
    close(fds[1]);   /* IMPORTANTE: el padre tampoco escribe. Si quedara abierto, los
                        trabajadores nunca verian EOF y el programa no terminaria. */

    /* 6) Trabajadores (consumidores). Heredan solo el extremo de lectura. */
    for (int i = 0; i < workers; i++) {
        p = fork();
        if (p < 0) die("fork");
        if (p == 0) {
            sigprocmask(SIG_SETMASK, &orig, NULL);
            signal(SIGTERM, SIG_DFL); signal(SIGINT, SIG_DFL); signal(SIGCHLD, SIG_DFL);
            run_worker(fds[0], i, slow_ms);
        }
        kids[nkids++] = (kid_t){ p, "trabajador", i, 1, 0 };
    }
    close(fds[0]);   /* el padre ya no necesita el pipe */

    printf("[supervisor] productor=%d trabajadores=", kids[0].pid);
    for (int i = 1; i < nkids; i++) printf("%d%s", kids[i].pid, i + 1 < nkids ? "," : "\n");

    /* 7) Esperar. */
    if (no_reap) {
        /* Demostracion: sin waitpid, los hijos que terminan quedan como zombies <defunct>. */
        printf("[supervisor] --no-reap: NO recojo hijos. Mire 'ps' o 'midistro-zombies' en otra terminal (20 s)...\n");
        sleep(20);
        printf("[supervisor] fin de la espera; al salir, init adoptara y recogera a los zombies.\n");
        return 0;
    }

    int term_sent = 0;
    while (live_children > 0) {
        if (got_term && !term_sent) {
            printf("[supervisor] recibi senal %d (%s): apagado ordenado, reenvio SIGTERM a los hijos\n",
                   (int)term_signo, strsignal(term_signo));
            for (int i = 0; i < nkids; i++)
                if (kids[i].alive) kill(kids[i].pid, SIGTERM);
            term_sent = 1;
        }
        sigsuspend(&orig);      /* desbloquea y duerme atomicamente hasta que llegue una senal */
    }
    double elapsed = now() - t0;

    /* 8) Informe. */
    for (int i = 0; i < nkids; i++) {
        char d[96];
        describe(&kids[i], d, sizeof d);
        if (kids[i].idx >= 0) printf("[supervisor] %s %d (pid=%d) %s\n", kids[i].role, kids[i].idx, kids[i].pid, d);
        else                  printf("[supervisor] %s (pid=%d) %s\n", kids[i].role, kids[i].pid, d);
    }

    long expected_jobs = (limit - 2) / chunk + 1;
    printf("---------------- RESULTADO ----------------\n");
    printf("primos en [2,%ld]      : %ld\n", limit, sh->total_primes);
    printf("trozos procesados      : %ld de %ld esperados\n", sh->jobs_done, expected_jobs);
    for (int i = 0; i < workers; i++) printf("  trabajador %d        : %ld trozos\n", i, sh->per_worker[i]);
    printf("tiempo paralelo        : %.3f s\n", elapsed);

    int ok = (sh->jobs_done == expected_jobs) && !got_term;
    if (verify && !got_term) {
        double s0 = now();
        long ref = count_primes(2, limit);
        double ser = now() - s0;
        printf("verificacion serial    : %ld primos en %.3f s  (aceleracion x%.2f)\n", ref, ser, ser / elapsed);
        if (ref != sh->total_primes) ok = 0;
    }
    if (got_term) { printf("ESTADO: INTERRUMPIDO por senal (resultado parcial)\n"); return 128 + term_signo; }
    printf("ESTADO: %s\n", ok ? "CORRECTO" : "INCORRECTO (se perdieron actualizaciones o trozos)");
    return ok ? 0 : 1;
}
