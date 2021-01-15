/* ----------------------------------------------------------------------- *
 *
 *   Copyright 2000 Transmeta Corporation - All Rights Reserved
 *   Copyright 2004-2008 H. Peter Anvin - All Rights Reserved
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
 *   Boston MA 02110-1301, USA; either version 2 of the License, or
 *   (at your option) any later version; incorporated herein by reference.
 *
 * ----------------------------------------------------------------------- */

/*
 * wrmsr.c
 *
 * Utility to write to an MSR.
 */

#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <getopt.h>
#include <inttypes.h>
#include <sys/types.h>

#include "version.h"

static const struct option long_options[] = {
	{"help",	0, 0, 'h'},
	{"version",	0, 0, 'V'},
	{"all",		0, 0, 'a'},
	{"processor",	1, 0, 'p'},
	{"cpu",		1, 0, 'p'},
	{0, 0, 0, 0}
};
static const char short_options[] = "hVap:";

static const char *proc_stat = "/proc/stat";
const char *program;

static void usage(void)
{
	fprintf(stderr, "Usage: %s [options] regno value...\n"
		"  --help         -h  Print this help\n"
		"  --version      -V  Print current version\n"
		"  --all          -a  all processors\n"
		"  --processor #  -p  Select processor number (default 0)\n",
		program);
}

static void wrmsr_on_cpu(uint32_t reg, uint64_t data, int cpu)
{
	int fd;
	char msr_file_name[64];

	sprintf(msr_file_name, "/dev/cpu/%d/msr", cpu);
	fd = open(msr_file_name, O_WRONLY);
	if (fd < 0) {
		if (errno == ENXIO) {
			fprintf(stderr, "wrmsr: No CPU %d\n", cpu);
			exit(2);
		} else if (errno == EIO) {
			fprintf(stderr, "wrmsr: CPU %d doesn't support MSRs\n",
				cpu);
			exit(3);
		} else if (errno == ENOENT) {
			fprintf(stderr, "wrmsr: %s doesn't exist\n", msr_file_name);
			exit(4);
		} else {
			perror("wrmsr: open");
			exit(127);
		}
	}
	if (pwrite(fd, &data, sizeof data, reg) != sizeof data) {
		if (errno == EIO) {
			fprintf(stderr,
				"wrmsr: CPU %d cannot set MSR "
				"0x%08"PRIx32" to 0x%016"PRIx64"\n",
				cpu, reg, data);
			exit(5);
		} else {
			perror("wrmsr: pwrite");
			exit(127);
		}
	}
	close(fd);
}


static void wrmsr_on_all_cpus(uint32_t reg, uint64_t data)
{
	FILE *fp;
	int retval;

	fp = fopen(proc_stat, "r");
	if (fp == NULL) {
		perror(proc_stat);
		exit(-1);
	}

	retval = fscanf(fp, "cpu %*d %*d %*d %*d %*d %*d %*d %*d %*d %*d\n");
	if (retval != 0) {
		perror("/proc/stat format");
		exit(-1);
	}

	for (;;) {
		int cpu;

		retval = fscanf(fp, "cpu%u %*d %*d %*d %*d %*d %*d %*d %*d "
			"%*d %*d\n", &cpu);
		if (retval != 1)
			return;

		wrmsr_on_cpu(reg, data, cpu);
	}
	fclose(fp);
}

int main(int argc, char *argv[])
{
	uint32_t reg;
	uint64_t data;
	int c;
	int cpu = 0;
	unsigned long arg;
	char *endarg;

	program = argv[0];

	while ((c = getopt_long(argc, argv, short_options,
				long_options, NULL)) != -1) {
		switch (c) {
		case 'h':
			usage();
			exit(0);
		case 'V':
			fprintf(stderr, "%s: version %s\n", program,
				VERSION_STRING);
			exit(0);
		case 'a':
			cpu = -1;
			break;
		case 'p':
			arg = strtoul(optarg, &endarg, 0);
			if (*endarg || arg > 255) {
				usage();
				exit(127);
			}
			cpu = (int)arg;
			break;
		default:
			usage();
			exit(127);
		}
	}

	if (optind > argc - 2) {
		/* Should have at least two arguments */
		usage();
		exit(127);
	}

	reg = strtoul(argv[optind++], NULL, 0);

	while (optind < argc) {
		data = strtoull(argv[optind++], NULL, 0);
		if (cpu == -1)
			wrmsr_on_all_cpus(reg, data);
		else
			wrmsr_on_cpu(reg, data, cpu);
	}
	exit(0);
}
