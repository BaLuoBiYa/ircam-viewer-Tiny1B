/*
 * Tiny1B UVC vendor controls for ircam-viewer.
 *
 * The camera exposes a vendor mailbox on endpoint 0:
 *   OUT: bmRequestType=0x41, bRequest=0x20, wValue=index, wIndex=cmd
 *   IN:  bmRequestType=0xC1, bRequest=0x19, wValue=index, wIndex=cmd
 *
 * This module resolves the /dev/videoN node back to its /dev/bus/usb/BBB/DDD
 * parent and sends the one-byte shutter settings used by the Tiny1B.
 */
#include "uvc.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <linux/usbdevice_fs.h>

#define UVC_TIMEOUT_MS 1000
#define UVC_CMD_SHUTTER 0x0345
#define UVC_CMD_SHUTTER_CFG 0x03C4
#define UVC_CMD_SHUTTER_STATUS 0x038A

static int read_int_file(const char *dir, const char *name, int *out)
{
	char path[PATH_MAX];
	FILE *f;
	int value;

	if (snprintf(path, sizeof(path), "%s/%s", dir, name) >=
	    (int)sizeof(path))
		return -1;

	f = fopen(path, "r");
	if (!f)
		return -1;

	if (fscanf(f, "%d", &value) != 1) {
		fclose(f);
		return -1;
	}

	fclose(f);
	*out = value;
	return 0;
}

static int find_usb_parent(const char *video_dev, int *bus, int *dev)
{
	char real[PATH_MAX];
	char sys[PATH_MAX];
	char dir[PATH_MAX];
	const char *base;
	char *slash;

	if (!realpath(video_dev, real))
		return -1;

	base = strrchr(real, '/');
	base = base ? base + 1 : real;

	if (snprintf(sys, sizeof(sys), "/sys/class/video4linux/%s/device",
		     base) >= (int)sizeof(sys))
		return -1;

	if (!realpath(sys, dir))
		return -1;

	for (;;) {
		if (read_int_file(dir, "busnum", bus) == 0 &&
		    read_int_file(dir, "devnum", dev) == 0)
			return 0;

		slash = strrchr(dir, '/');
		if (!slash || slash == dir)
			return -1;

		*slash = '\0';
	}
}

int uvc_open_for_video(const char *video_dev)
{
	char path[PATH_MAX];
	int bus;
	int dev;

	if (find_usb_parent(video_dev, &bus, &dev)) {
		if (!errno)
			errno = ENODEV;
		return -1;
	}

	if (snprintf(path, sizeof(path), "/dev/bus/usb/%03d/%03d", bus, dev) >=
	    (int)sizeof(path)) {
		errno = ENAMETOOLONG;
		return -1;
	}

	return open(path, O_RDWR | O_CLOEXEC);
}

static int ctrl_out_u8(int fd, uint16_t cmd, uint16_t index, uint8_t value)
{
	struct usbdevfs_ctrltransfer ctrl = {
		.bRequestType = 0x41,
		.bRequest = 0x20,
		.wValue = index,
		.wIndex = cmd,
		.wLength = 1,
		.timeout = UVC_TIMEOUT_MS,
		.data = &value,
	};

	return ioctl(fd, USBDEVFS_CONTROL, &ctrl) >= 0 ? 0 : -1;
}

static int ctrl_in_u8(int fd, uint16_t cmd, uint16_t index, uint8_t *value)
{
	struct usbdevfs_ctrltransfer ctrl = {
		.bRequestType = 0xC1,
		.bRequest = 0x19,
		.wValue = index,
		.wIndex = cmd,
		.wLength = 1,
		.timeout = UVC_TIMEOUT_MS,
		.data = value,
	};

	return ioctl(fd, USBDEVFS_CONTROL, &ctrl) == 1 ? 0 : -1;
}

int uvc_shutter_set_auto(int fd, int on)
{
	return ctrl_out_u8(fd, UVC_CMD_SHUTTER_CFG, 0x0100, on ? 1 : 0);
}

int uvc_shutter_set_min_interval(int fd, int value)
{
	return ctrl_out_u8(fd, UVC_CMD_SHUTTER_CFG, 0x0102, (uint8_t)value);
}

int uvc_shutter_set_max_interval(int fd, int value)
{
	return ctrl_out_u8(fd, UVC_CMD_SHUTTER_CFG, 0x0103, (uint8_t)value);
}

int uvc_shutter_set_vtemp_thd(int fd, int value)
{
	return ctrl_out_u8(fd, UVC_CMD_SHUTTER_CFG, 0x0101, (uint8_t)value);
}

int uvc_shutter_manual(int fd)
{
	/*
	 * libiruvc sends a one-byte dummy payload for this logically
	 * zero-length command; match that behavior here.
	 */
	return ctrl_out_u8(fd, UVC_CMD_SHUTTER, 0x0000, 0);
}

int uvc_shutter_get_auto(int fd)
{
	uint8_t value = 0;

	if (ctrl_in_u8(fd, UVC_CMD_SHUTTER_STATUS, 0x0100, &value))
		return -1;

	return value;
}
