#!/bin/sh
# Install raw-USB access for the Tiny1B / CT256 thermal camera (0bda:3901).
# Run this once with sudo; after that ircam-viewer can use the shutter
# controls as a normal user.

set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run: sudo $0" >&2
	exit 1
fi

# 70-* runs before 73-seat-late.rules, which is what actually applies the
# uaccess ACL.  A 99-* rule adds TAG+="uaccess" too late to have any effect.
OLD_RULE=/etc/udev/rules.d/99-tiny1b.rules
RULE=/etc/udev/rules.d/70-tiny1b.rules

rm -f "$OLD_RULE"

cat > "$RULE" <<'RULE_EOF'
# Tiny1B / CT256 thermal camera (Realtek 0bda:3901)
# 70-* so the uaccess tag is seen by 73-seat-late.rules.
# GROUP/MODE is a fallback for users who are in the video group.
SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="3901", MODE="0660", GROUP="video", TAG+="uaccess"
RULE_EOF

udevadm control --reload-rules
udevadm trigger --action=change --subsystem-match=usb
udevadm settle || true

echo "Installed $RULE"
echo "Removed $OLD_RULE (if it existed)"
echo
echo "Unplug and replug the camera once, then check:"
echo "  lsusb -d 0bda:3901"
echo "  getfacl /dev/bus/usb/BBB/DDD"
echo
echo "If there is still no 'user:luo' ACL, add your user to the video group:"
echo "  sudo usermod -aG video \$USER"
echo "then log out and back in."
