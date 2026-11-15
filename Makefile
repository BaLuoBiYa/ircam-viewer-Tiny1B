CC ?= gcc

CFLAGS ?= -O3
BASE_CFLAGS = -std=c11 -pedantic -D_GNU_SOURCE -D_REENTRANT
CFLAGS += $(BASE_CFLAGS)

WFLAGS = -Wall -Wextra -Wstrict-prototypes -Wmissing-prototypes -Wno-switch \
	 -Wmissing-declarations -Werror=implicit -Wdeclaration-after-statement \
	 -Wduplicated-cond -Wduplicated-branches -Wlogical-op -Wrestrict \
	 -Wnull-dereference -Wjump-misses-init -Wdouble-promotion -Wshadow \
	 -Wformat=2 -Wstrict-aliasing -Wno-unknown-warning-option \
	 -Wno-format-nonliteral -Wpedantic

SRC_DIR ?= src
BUILD_DIR ?= build
OBJ_DIR := $(BUILD_DIR)/obj
NOSDL_OBJ_DIR := $(BUILD_DIR)/obj-nosdl
BIN := $(BUILD_DIR)/ircam
NOSDL_BIN := $(BUILD_DIR)/ircam-nosdl

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
DIST_DIR ?= dist
VERSION := $(shell dpkg-parsechangelog -SVersion 2>/dev/null)

SDL_C_SRCS = main.c dev.c v4l2.c lavc.c inet.c sdl.c fontcache.c uvc.c
SDL_OBJS = $(addprefix $(OBJ_DIR)/,$(SDL_C_SRCS:.c=.o)) $(OBJ_DIR)/builtin.o
NOSDL_C_SRCS = main.c dev.c v4l2.c lavc.c inet.c uvc.c
NOSDL_OBJS = $(addprefix $(NOSDL_OBJ_DIR)/,$(NOSDL_C_SRCS:.c=.o))
NOSDL_CFLAGS = -DIRCAM_NOSDL -Wno-unused-parameter

.PHONY: all nosdl debug format clean install package clean-old-packages checksums

all: $(BIN) $(BUILD_DIR)/util/kfwd $(BUILD_DIR)/util/sisyphus
nosdl: $(NOSDL_BIN)

debug:
	$(MAKE) BUILD_DIR=build/debug \
		CFLAGS="-g -Og -fsanitize=address $(BASE_CFLAGS)" \
		LDFLAGS="$(LDFLAGS) -fsanitize=address" all

FMTSRCS = $(addprefix $(SRC_DIR)/,inet.c inet.h lavc.c lavc.h main.c sdl.c \
	  sdl.h v4l2.c v4l2.h dev.c dev.h uvc.c uvc.h util/kfwd.c)

format:
	clang-format -i $(FMTSRCS)

$(BIN): $(SDL_OBJS)
	@mkdir -p $(dir $@)
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS) -lSDL2 -lSDL2_ttf -lavcodec -lavutil -lavformat

$(NOSDL_BIN): $(NOSDL_OBJS)
	@mkdir -p $(dir $@)
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS) -lavcodec -lavutil -lavformat

$(BUILD_DIR)/util/kfwd: $(OBJ_DIR)/util/kfwd.o
	@mkdir -p $(dir $@)
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)

$(BUILD_DIR)/util/sisyphus: $(OBJ_DIR)/util/sisyphus.o
	@mkdir -p $(dir $@)
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)

$(SRC_DIR)/gamma.h: $(SRC_DIR)/util/gamma.py
	$(SRC_DIR)/util/gamma.py > $@

$(OBJ_DIR)/sdl.o: $(SRC_DIR)/gamma.h

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $< $(CPPFLAGS) $(CFLAGS) $(WFLAGS) -c -o $@

$(NOSDL_OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $< $(CPPFLAGS) $(CFLAGS) $(NOSDL_CFLAGS) $(WFLAGS) -c -o $@

# Don't enable any warnings for FC_FontCache
$(OBJ_DIR)/fontcache.o: $(SRC_DIR)/fontcache.c
	@mkdir -p $(dir $@)
	$(CC) $< $(CPPFLAGS) $(CFLAGS) -c -o $@

$(OBJ_DIR)/builtin.o: $(SRC_DIR)/builtin.s $(SRC_DIR)/fonts/deja_vu_sans_mono.ttf
	@mkdir -p $(dir $@)
	$(CC) $< -c -o $@

clean:
	rm -rf $(BUILD_DIR)
	rm -f ircam ircam-nosdl *.o

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(BINDIR)/ircam

clean-old-packages:
	@test -n "$(VERSION)" || { echo "cannot determine package version" >&2; exit 1; }
	@mkdir -p "$(DIST_DIR)"
	@find "$(DIST_DIR)" -maxdepth 1 -type f \
		\( -name 'ircam-viewer*.deb' -o -name 'ircam-viewer*.ddeb' \
		   -o -name 'ircam-viewer*.changes' -o -name 'ircam-viewer*.buildinfo' \) \
		! -name "*$(VERSION)*" -print -delete
	@rm -f "$(DIST_DIR)/SHA256SUMS"

package: clean-old-packages
	./scripts/package-deb.sh

checksums:
	@test -n "$(VERSION)" || { echo "cannot determine package version" >&2; exit 1; }
	@cd "$(DIST_DIR)" && sha256sum ircam-viewer_$(VERSION)_*.deb > SHA256SUMS
	@cat "$(DIST_DIR)/SHA256SUMS"
