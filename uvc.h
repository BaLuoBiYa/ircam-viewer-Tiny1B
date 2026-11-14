/*
 * Tiny1B UVC vendor controls for ircam-viewer.
 *
 * These commands are reverse-engineered from the Tiny1B Linux SDK and are
 * intentionally kept in a small standalone module so the viewer does not
 * depend on libiruvc.
 */
#pragma once

int uvc_open_for_video(const char *video_dev);
int uvc_shutter_set_auto(int fd, int on);
int uvc_shutter_set_min_interval(int fd, int value);
int uvc_shutter_set_max_interval(int fd, int value);
int uvc_shutter_set_vtemp_thd(int fd, int value);
int uvc_shutter_manual(int fd);
int uvc_shutter_get_auto(int fd);
