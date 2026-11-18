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
native-probes: $(OUT)/ffi_smoke_68040 $(OUT)/gfos_exec_port_probe_68040 $(OUT)/gfos_transport_selftest_68040 $(OUT)/gfos_sync_selftest_68040

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

$(OUT)/gfos_sync.o: src/sync/gfos_sync.c src/sync/gfos_sync.h
	@mkdir -p $(OUT)
	$(CC) $(TARGET_CFLAGS) -Wall -Wextra -I $(NDK_INCLUDE) -I src/sync -c $< -o $@

$(OUT)/libgfosfoundationsync.a: $(OUT)/gfos_sync.o
	$(SDK_PREFIX)/bin/m68k-amigaos-ar rcs $@ $<

$(OUT)/gfos_sync_selftest_68040: tests/sync/gfos_sync_selftest.c $(OUT)/libgfosfoundationsync.a
	@mkdir -p $(OUT)
	$(CC) $(TARGET_CFLAGS) -Wall -Wextra -I $(NDK_INCLUDE) -I src/sync $< $(OUT)/libgfosfoundationsync.a -o $@

# Bridge is an Objective-C source object, not a linked Foundation executable.
# Compile only after applying the native GNUstep Base patches and configure.
GNUSTEP_BASE_DIR ?= ../gnustep-base
$(OUT)/GFOSFoundationEndpoint.o: src/foundation/GFOSFoundationEndpoint.m src/foundation/GFOSFoundationEndpoint.h src/ipc/gfos_transport.h
	@mkdir -p $(OUT)
	$(CC) -x objective-c $(TARGET_CFLAGS) -I $(GNUSTEP_BASE_DIR)/Headers -I $(GNUSTEP_BASE_DIR)/Source -I $(NDK_INCLUDE) -I src/ipc -I src/foundation -c $< -o $@

$(OUT)/GFOSFoundationLock.o: src/sync/GFOSFoundationLock.m src/sync/GFOSFoundationLock.h src/sync/gfos_sync.h
	@mkdir -p $(OUT)
	$(CC) -x objective-c $(TARGET_CFLAGS) -I $(GNUSTEP_BASE_DIR)/Headers -I $(NDK_INCLUDE) -I src/sync -c $< -o $@

$(OUT)/GFOSNSMessagePort.o: src/foundation/GFOSNSMessagePort.m src/foundation/GFOSNSMessagePort.h src/ipc/gfos_transport.h
	@mkdir -p $(OUT)
	$(CC) -x objective-c $(TARGET_CFLAGS) -I $(GNUSTEP_BASE_DIR)/Headers -I $(NDK_INCLUDE) -I src/ipc -I src/foundation -c $< -o $@

$(OUT)/GFOSNSMessagePortNameServer.o: src/foundation/GFOSNSMessagePortNameServer.m src/foundation/GFOSNSMessagePort.h src/ipc/gfos_transport.h
	@mkdir -p $(OUT)
	$(CC) -x objective-c $(TARGET_CFLAGS) -I $(GNUSTEP_BASE_DIR)/Headers -I $(NDK_INCLUDE) -I src/ipc -I src/foundation -c $< -o $@

$(OUT)/libgfosfoundationports.a: $(OUT)/GFOSNSMessagePort.o $(OUT)/GFOSNSMessagePortNameServer.o
	$(SDK_PREFIX)/bin/m68k-amigaos-ar rcs $@ $^

.PHONY: foundation-ports
foundation-ports: $(OUT)/libgfosfoundationports.a

# Diagnostic link of GNUstep Base core-only archive plus real GFOS local
# NSMessagePort classes. These link tests must be executed on the guest
# before they qualify as passed runtime tests.
GFOS_BASE_CORE_ARCHIVE ?= $(GNUSTEP_BASE_DIR)/Source/obj/libgnustep-base.a
GFOS_DEPS_LIB ?= $(SDK_PREFIX)/m68k-amigaos/port-deps/lib
GFOS_LIBNIX_LIB ?= $(SDK_PREFIX)/m68k-amigaos/libnix/lib

$(OUT)/foundation_smoke.o: tests/foundation/foundation_smoke.m
	@mkdir -p $(OUT)
	$(CC) -x objective-c $(TARGET_CFLAGS) -I $(GNUSTEP_BASE_DIR)/Headers -I $(GNUSTEP_BASE_DIR)/Source -I $(NDK_INCLUDE) -c $< -o $@

$(OUT)/foundation_ipc_smoke.o: tests/foundation/foundation_ipc_smoke.m src/foundation/GFOSNSMessagePort.h
	@mkdir -p $(OUT)
	$(CC) -x objective-c $(TARGET_CFLAGS) -I $(GNUSTEP_BASE_DIR)/Headers -I src/foundation -I $(NDK_INCLUDE) -c $< -o $@

$(OUT)/foundation_smoke_68040: $(OUT)/foundation_smoke.o $(OUT)/libgfosfoundationports.a $(OUT)/libgfosfoundationipc.a
	$(CC) -m68040 -m68881 -noixemul $< -L $(GFOS_DEPS_LIB) -L $(GFOS_LIBNIX_LIB) \
	-Wl,--start-group -Wl,--whole-archive $(GFOS_BASE_CORE_ARCHIVE) -Wl,--no-whole-archive \
	$(OUT)/libgfosfoundationports.a $(OUT)/libgfosfoundationipc.a $(FFI_PREFIX)/lib/libffi.a \
	-lobjc -lpthread -lm -lz -lsocket -Wl,--end-group -o $@

$(OUT)/foundation_ipc_smoke_68040: $(OUT)/foundation_ipc_smoke.o $(OUT)/libgfosfoundationports.a $(OUT)/libgfosfoundationipc.a
	$(CC) -m68040 -m68881 -noixemul $< -L $(GFOS_DEPS_LIB) -L $(GFOS_LIBNIX_LIB) \
	-Wl,--start-group -Wl,--whole-archive $(GFOS_BASE_CORE_ARCHIVE) -Wl,--no-whole-archive \
	$(OUT)/libgfosfoundationports.a $(OUT)/libgfosfoundationipc.a $(FFI_PREFIX)/lib/libffi.a \
	-lobjc -lpthread -lm -lz -lsocket -Wl,--end-group -o $@

$(OUT)/foundation_date_probe.o: tests/foundation/foundation_date_probe.m
	@mkdir -p $(OUT)
	$(CC) -x objective-c $(TARGET_CFLAGS) -I $(GNUSTEP_BASE_DIR)/Headers -c $< -o $@

$(OUT)/foundation_date_probe_68040: $(OUT)/foundation_date_probe.o $(OUT)/libgfosfoundationports.a $(OUT)/libgfosfoundationipc.a
	$(CC) -m68040 -m68881 -noixemul $< -L $(GFOS_DEPS_LIB) -L $(GFOS_LIBNIX_LIB) \
	-Wl,--start-group -Wl,--whole-archive $(GFOS_BASE_CORE_ARCHIVE) -Wl,--no-whole-archive \
	$(OUT)/libgfosfoundationports.a $(OUT)/libgfosfoundationipc.a $(FFI_PREFIX)/lib/libffi.a \
	-lobjc -lpthread -lm -lz -lsocket -Wl,--end-group -o $@

.PHONY: foundation-core-link
foundation-core-link: $(OUT)/foundation_smoke_68040 $(OUT)/foundation_ipc_smoke_68040 $(OUT)/foundation_date_probe_68040

.PHONY: foundation-bridge
foundation-bridge: $(OUT)/GFOSFoundationEndpoint.o $(OUT)/GFOSFoundationLock.o

clean:
	rm -rf $(OUT)
