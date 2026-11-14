# ircam-viewer（Tiny1B 修改版）

本工程是基于 [jcalvinowens/ircam-viewer](https://github.com/jcalvinowens/ircam-viewer)
的修改版本，

<https://github.com/jcalvinowens/ircam-viewer>

本工程基于上游提交 `8f60f06`（Add support for Thermal Master P2）修改而来。

## 修改

- 增加 Tiny1B / CT256 的 UVC vendor 快门控制，不依赖 `libiruvc`。
- 增加快门设置持久化，支持从命令行或配置文件加载。
- 修正 Tiny1B 温度原始值的缩放（Kelvin × 16），默认显示摄氏度。
- 将输出旋转从 180° 翻转改为 90° 步进旋转。
- 增加 Debian 打包文件，提供桌面入口、图标和 man page。

## 目录结构

```text
.
├── src/                 # C 源码、头文件和内嵌字体
│   ├── fonts/
│   └── util/            # gamma.py、kfwd、sisyphus
├── build/               # make 生成的编译产物（不纳入版本控制）
├── dist/                # 打包产物（不纳入版本控制）
├── scripts/             # 打包辅助脚本
├── debian/              # Debian 打包文件
├── Makefile
├── README.md
└── LICENSE
```

## 构建

依赖：

```sh
sudo apt install libsdl2-dev libsdl2-ttf-dev \
    libavcodec-dev libavformat-dev libavutil-dev
```

构建 GUI 版本：

```sh
make -j"$(nproc)"
```

产物：

```text
build/ircam
```

无 SDL 的 headless 版本：

```sh
make nosdl
```

产物：

```text
build/ircam-nosdl
```

ASan 调试版本：

```sh
make debug
```

产物：

```text
build/debug/ircam
```

安装到系统：

```sh
sudo make install
```

清理：

```sh
make clean
```

## Tiny1B 快门控制

使用前需要允许当前用户访问摄像头的 raw USB 设备。可以临时使用 `sudo`，也可以
添加一条 udev 规则。下面只是本机示例，正式 deb 包不会安装这条规则：

```udev
# /etc/udev/rules.d/70-tiny1b.rules
# Tiny1B / CT256 (0bda:3901)
SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="3901", MODE="0660", GROUP="video", TAG+="uaccess"
```

使用 `70-` 前缀是为了让 `uaccess` 在 `73-seat-late.rules` 之前生效。添加后重新
加载规则，并重新插拔摄像头：

```sh
sudo udevadm control --reload-rules
sudo udevadm trigger --action=change --subsystem-match=usb
```

```sh
# 读取当前自动快门状态
./build/ircam -d /dev/video4 --shutter-auto-get

# 开启自动快门，设置最小/最大间隔
./build/ircam -d /dev/video4 \
    --shutter-auto 1 \
    --shutter-min 60 \
    --shutter-max 120

# 关闭自动快门并触发一次手动校准
./build/ircam -d /dev/video4 \
    --shutter-auto 0 \
    --shutter-manual
```

选项：

| 选项 | 说明 |
|---|---|
| `--shutter-auto 0 或 1` | 开启或关闭固件自动快门 |
| `--shutter-min N` | 最小间隔，固件定义值，范围 0..255 |
| `--shutter-max N` | 最大间隔，固件定义值，范围 0..255 |
| `--shutter-vtemp-thd N` | 传感器温度阈值，范围 0..255 |
| `--shutter-manual` | 触发一次手动快门校准 |
| `--shutter-auto-get` | 打印当前自动快门标志 |

## 快门配置持久化

配置文件默认位置：

```text
$XDG_CONFIG_HOME/ircam-viewer.conf
```

未设置 `XDG_CONFIG_HOME` 时：

```text
$HOME/.config/ircam-viewer.conf
```

保存当前设置：

```sh
./build/ircam -d /dev/video4 \
    --shutter-auto 1 \
    --shutter-min 60 \
    --shutter-max 120 \
    --shutter-save
```

配置文件格式：

```text
shutter_auto=1
shutter_min=60
shutter_max=120
```

相关选项：

- `--shutter-config PATH`：使用指定配置文件。
- `--shutter-no-config`：本次运行忽略配置文件。
- `--shutter-save`：把当前有效设置写回配置文件。

命令行参数优先于配置文件。

## 显示与旋转

- 默认单位为摄氏度，按 `F` 切换华氏度。
- 按 `U` 每次旋转 90°。
- 启动时可用 `-r 0|90|180|270` 指定初始旋转角度。

## Debian 打包

`debian/` 目录用于构建通用的 `ircam-viewer` 包：

```sh
sudo apt install debhelper dpkg-dev
make package
```

`make package` 会调用 `dpkg-buildpackage`，并把 `.deb`、`.ddeb`、`.changes`、
`.buildinfo` 以及构建日志统一放进：

```text
dist/
```

包内包含：

```text
/usr/bin/ircam
/usr/share/applications/ircam-viewer.desktop
/usr/share/icons/hicolor/scalable/apps/ircam-viewer.svg
/usr/share/icons/hicolor/256x256/apps/ircam-viewer.png
/usr/share/man/man1/ircam.1.gz
/usr/share/doc/ircam-viewer/
```

## 许可

本工程沿用上游的 GPL-3.0-or-later 许可，详见 [LICENSE](LICENSE)。上游版权归
原作者所有；本分支的修改部分见 `debian/copyright`。
