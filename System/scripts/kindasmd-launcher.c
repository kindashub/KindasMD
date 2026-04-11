/* KindasMD.app main — Mach-O so Dock / Launch Services reliably exec kindasmd (bash script). */
#include <errno.h>
#include <limits.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
	const char *home = getenv("HOME");
	char script[PATH_MAX];

	if (home == NULL || home[0] == '\0') {
		struct passwd *pw = getpwuid(getuid());
		if (pw == NULL || pw->pw_dir == NULL) {
			(void)fprintf(stderr, "KindasMD: no HOME\n");
			return 1;
		}
		home = pw->pw_dir;
	}

	if ((size_t)snprintf(script, sizeof(script), "%s/MBP-Mods/KindasMD/system/kindasmd", home)
	    >= sizeof(script)) {
		(void)fprintf(stderr, "KindasMD: path too long\n");
		return 1;
	}

	execl("/bin/bash", "bash", script, (char *)NULL);
	(void)fprintf(stderr, "KindasMD: exec %s: %s\n", script, strerror(errno));
	return errno == 0 ? 111 : errno;
}
