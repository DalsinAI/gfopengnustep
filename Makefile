# GFOpenGNUstep native GFOS qualification targets.
# This is a build receipt for genuine GCC16 m68k-amigaos executables,
# not an assertion that the full GNUstep Base port is ready to release.
SDK_PREFIX ?= /opt/gfopen-gcc16
NDK_INCLUDE ?= $(SDK_PREFIX)/m68k-amigaos/ndk-include.vendor
FFI_PREFIX ?= /opt/gfopen-libffi
CC := $(SDK_PREFIX)/bin/m68k-amigaos-gcc
OUT ?= build/gfos
TARGET_CFLAGS := -std=gnu11 -O2 -m68040 -m68881 -noixemul

.PHONY: all native-probes clean
all: native-probes
native-probes: $(OUT)/ffi_smoke_68040 $(OUT)/gfos_exec_port_probe_68040 $(OUT)/gfos_transport_selftest_68040

$(OUT)/ffi_smoke_68040: tests/ffi_smoke.c
	@mkdir -p $(OUT)
	$(CC) $(TARGET_CFLAGS) -I $(FFI_PREFIX)/include $< $(FFI_PREFIX)/lib/libffi.a -lm -o $@

$(OUT)/gfos_exec_port_probe_68040: tests/ipc/gfos_exec_port_probe.c
	@mkdir -p $(OUT)
	$(CC) $(TARGET_CFLAGS) -I $(NDK_INCLUDE) $< -o $@

$(OUT)/gfos_transport.o: src/ipc/gfos_transport.c src/ipc/gfos_transport.h
	@mkdir -p $(OUT)
	$(CC) $(TARGET_CFLAGS) -Wall -Wextra -I $(NDK_INCLUDE) -I src/ipc -c $< -o $@

$(OUT)/libgfosfoundationipc.a: $(OUT)/gfos_transport.o
	$(SDK_PREFIX)/bin/m68k-amigaos-ar rcs $@ $<

$(OUT)/gfos_transport_selftest_68040: tests/ipc/gfos_transport_selftest.c $(OUT)/libgfosfoundationipc.a
	@mkdir -p $(OUT)
	$(CC) $(TARGET_CFLAGS) -Wall -Wextra -I $(NDK_INCLUDE) -I src/ipc $< $(OUT)/libgfosfoundationipc.a -o $@

clean:
	rm -rf $(OUT)
