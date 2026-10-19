/*
 * QDeck: Lightweight Wayland/evdev lockstate monitor for keyboard LEDs
 */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <glob.h>
#include <string.h>

static int open_led(const char *pattern) {
    glob_t g;
    int fd = -1;
    if (glob(pattern, 0, NULL, &g) == 0 && g.gl_pathc > 0) {
        fd = open(g.gl_pathv[0], O_RDONLY);
    }
    globfree(&g);
    return fd;
}

static int read_led_val(int fd) {
    char buf[16];
    if (fd < 0) return -1;
    if (lseek(fd, 0, SEEK_SET) == (off_t)-1) return -1;
    int n = read(fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        if (buf[0] == '1') return 1;
        if (buf[0] == '0') return 0;
    }
    return -1;
}

int main(void) {
    int num_fd = open_led("/sys/class/leds/*numlock*/brightness");
    int caps_fd = open_led("/sys/class/leds/*capslock*/brightness");

    int last_num = read_led_val(num_fd);
    int last_caps = read_led_val(caps_fd);

    struct pollfd pfds[2];

    while (1) {
        int nfds = 0;
        if (num_fd >= 0) {
            pfds[nfds].fd = num_fd;
            pfds[nfds].events = POLLPRI | POLLERR;
            pfds[nfds].revents = 0;
            nfds++;
        } else {
            num_fd = open_led("/sys/class/leds/*numlock*/brightness");
            last_num = read_led_val(num_fd);
        }

        if (caps_fd >= 0) {
            pfds[nfds].fd = caps_fd;
            pfds[nfds].events = POLLPRI | POLLERR;
            pfds[nfds].revents = 0;
            nfds++;
        } else {
            caps_fd = open_led("/sys/class/leds/*capslock*/brightness");
            last_caps = read_led_val(caps_fd);
        }

        // Poll with 60ms timeout: wakes up immediately on kernel sysfs_notify,
        // and falls through every 60ms with zero CPU overhead.
        poll(pfds, nfds, 60);

        if (num_fd >= 0) {
            int cur_num = read_led_val(num_fd);
            if (cur_num >= 0 && cur_num != last_num) {
                last_num = cur_num;
                printf("NUMLOCK:%s\n", cur_num ? "ON" : "OFF");
                fflush(stdout);
            }
        }

        if (caps_fd >= 0) {
            int cur_caps = read_led_val(caps_fd);
            if (cur_caps >= 0 && cur_caps != last_caps) {
                last_caps = cur_caps;
                printf("CAPSLOCK:%s\n", cur_caps ? "ON" : "OFF");
                fflush(stdout);
            }
        }
    }

    if (num_fd >= 0) close(num_fd);
    if (caps_fd >= 0) close(caps_fd);
    return 0;
}
