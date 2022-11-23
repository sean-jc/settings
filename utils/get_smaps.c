#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>

int main(int argc, char **argv)
{
	char smaps[50];
	int fd;

	sprintf(smaps, "/proc/%s/smaps", argv[1]);

	fd = open(smaps, O_RDONLY);
	if (fd < 0) {
		printf("open failed: %d\n", errno);
		exit(1);
	}

	/* point stdin at fd */
	dup2(fd, 0);
	close(fd);

	execl("/bin/cat", "cat", NULL);
	printf("execl failed: %d\n", errno);

	return 1;
}
