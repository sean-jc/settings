#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <sys/wait.h>
#include <sys/mman.h>

static int debug = 0;

#define mb()	__sync_synchronize()

#define __ALIGN_MASK(x,mask)	(((x)+(mask))&~(mask))
#define ALIGN(x,a)		__ALIGN_MASK(x,(typeof(x))(a)-1)

#define PAGE_SIZE		(1 << 12)
#define PAGE_ALIGN(addr)	ALIGN(addr, PAGE_SIZE)

#define THREAD_MAX	(int)(sizeof(long) * 8)
#define THREAD_NUM	8
#define COUNT_NUM	10
#define MEM_SIZE	(unsigned long long)(1 * 1024 * 1024 * 1024)

static void usage(void)
{
	printf("Usage:\n");
	printf("-c:	the thread number (default: %d, max: %d).\n", THREAD_NUM, THREAD_MAX);
	printf("-m:	the memory size (M) (default: %lld GB).\n", MEM_SIZE / 1024 / 1024 / 1024);
	printf("-t:	the memory write time (default: %d M).\n", 10);
	printf("-d:	enable debug output.\n");
}

static inline void dprint(char *fmt, ...)
{
	va_list arg;

	if (!debug)
		return;

	va_start(arg, fmt);
	vprintf(fmt, arg);
	va_end(arg);
}

static inline void fmt_die(char *fmt, ...)
{
	va_list arg;

	va_start(arg, fmt);
	vprintf(fmt, arg);
	va_end(arg);

	exit(-1);
}

static inline void die(char *s)
{
	fmt_die("%s", s);
}

static inline void *wmalloc_align(int size)
{
	void *p;

	p = mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

	if (p == MAP_FAILED) {
		perror("posix_memalign");
		die("posix_memalign fail.\n");
	}

	return p;
}

typedef uint64_t u64;

static inline u64 time_ns()
{
    struct timespec ts;

    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * (u64)1000000000 + ts.tv_nsec;
}

enum {
	ACTION_WAIT,
	ACTION_WRITE
};

struct thread_info {
	char *writemem;
	int pid;
	int ready;
	unsigned long long memsize;
};

struct thread_share {
	int action;
	unsigned long thread_num;
	unsigned long thread_bitmap;
	unsigned long long ram_size;
	struct thread_info ithread[THREAD_MAX];
};

static void wait_all_theads_ready(struct thread_share *tshare)
{
	unsigned long thread_num = tshare->thread_num;
	unsigned int seq;

	mb();
	for (seq = 0; seq < thread_num; seq++) {
		while (!tshare->ithread[seq].ready)
			;
		tshare->ithread[seq].ready = 0;
	}
}

static void action_set(struct thread_share *tshare, int action)
{
	mb();
	tshare->action = action;
}

static void __action_wait(struct thread_share *tshare, int action, int seq)
{
	mb();

	if (tshare->ithread[seq].ready) {
		printf("seq bit already set, BUG!.\n");
		die("seq bit already set, BUG!.\n");
	}

	tshare->ithread[seq].ready = 1;

	mb();
	while (tshare->action == action)
		;
}

static void action_wait(struct thread_share *tshare, int action, int seq)
{
	dprint("thread %d, call %s.\n", seq, __FUNCTION__);
	__action_wait(tshare, action, seq);
}

static void write_mem(struct thread_share *tshare, int seq)
{
	memset(tshare->ithread[seq].writemem, seq, tshare->ithread[seq].memsize);
}

static void action_write(struct thread_share *tshare, int action, int seq)
{
	dprint("thread %d, call %s.\n", seq, __FUNCTION__);

	write_mem(tshare, seq);
	action_wait(tshare, action, seq);
}

static void (*const action_handlers[])(struct thread_share *tshare, int action, int seq) = {
	[ACTION_WAIT] = action_wait,
	[ACTION_WRITE] = action_write,
};

static void thread_main(struct thread_share *tshare, int seq)
{
	unsigned long long memsize= PAGE_ALIGN(tshare->ram_size / tshare->thread_num);
	char *mem;

	mem = wmalloc_align(memsize);
	dprint("thread %d, memsize %lldM, mem %p.\n", seq, memsize / 1024 /1024, mem);

	tshare->ithread[seq].memsize = memsize;
	tshare->ithread[seq].writemem = mem;

	/* fill memeroy. */
	write_mem(tshare, seq);

	while (1) {
		int action = tshare->action;

		action_handlers[action](tshare, action, seq);
	}
}


static int run_cmd(char *cmd)
{
	int ret;

	if (!cmd)
		return 0;

	ret = fork();

	if (ret < 0)
		fmt_die("%s fork failed.\n", __FUNCTION__);
	if (ret > 0)
		return ret;

	system(cmd);
	exit (0);
}

int main(int argc, char *argv[])
{
	struct thread_share *tshare;
	unsigned long long ram_size;
	long opt;
	int i, count, thread_num;
	char *endptr, *extern_cmd = NULL;
	u64 total_time = 0;

	thread_num = THREAD_NUM;
	ram_size = MEM_SIZE;
	count = COUNT_NUM;

	while ((opt = getopt(argc, argv, "c:m:t:de:")) != -1) {
		switch (opt) {
		case 'c':
			thread_num = strtol(optarg, &endptr, 10);
			if (thread_num > THREAD_MAX)
				fmt_die("thread number can not more than %d.\n", THREAD_MAX);

			break;
		case 'm':
			ram_size = strtol(optarg, &endptr, 10);
			ram_size *= 1024 * 1024 * 1024;
			break;
		case 't':
			count = strtol(optarg, &endptr, 10);
			break;
		case 'd':
			debug = 1;
			break;
		case 'e':
			extern_cmd = optarg;
			break;
		default:
			usage();
			fmt_die("Unknown %c.\n", opt);
		}
	}

	printf("Thread:%d, Mem:%lldM, Time:%d Cmd:%s.\n", thread_num, ram_size / 1024 / 1024, count, extern_cmd);

	tshare = mmap(NULL,sizeof(*tshare), PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS, -1, 0);

	memset(tshare, 0, sizeof(*tshare));
	tshare->ram_size = ram_size;
	tshare->thread_num = thread_num;
	action_set(tshare, ACTION_WAIT);

	for (i = 0; i < thread_num; i++) {
		int ret = fork();

		if (ret < 0)
			fmt_die("fork thread [%d] failed.\n", i);

		if (!ret)
			thread_main(tshare, i);
		else {
			tshare->ithread[i].pid = ret;
			dprint("thread [%d]: PID %d.\n", i, ret);
		}
	}

	for (i = 0; i < count; i++) {
		u64 start, end;
		int pid = 0;

		wait_all_theads_ready(tshare);

		if (i & 0x1)
			pid = run_cmd(extern_cmd);

		start = time_ns();
		action_set(tshare, ACTION_WRITE);
		wait_all_theads_ready(tshare);
		end = time_ns();

		printf("The %d time: %ld ns.\n", i, end - start);
		total_time += end - start;
		if (pid)
			waitpid(pid, NULL, 0);
		action_set(tshare, ACTION_WAIT);
	}

	printf("Run %d times, Avg time:%ld ns.\n", count, total_time / count);

	for (i = 0; i < thread_num; i++)
		kill(tshare->ithread[i].pid, SIGKILL);

	wait(NULL);
	return 0;
}
