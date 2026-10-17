# Builds framebuffer.efi and loader.efi and regenerates ../WindowsEFIBinaries.swift.
# Needs clang and lld-link (brew install llvm lld). The binaries are committed, so this only
# needs to run after changing the C sources.
LLD_LINK ?= lld-link
# make DEBUG=1 adds bring-up markers on screen (see Mark() in the sources)
ifdef DEBUG
CFLAGS += -DDEBUG_MARKS
endif
CFLAGS += -target aarch64-unknown-windows -ffreestanding -fshort-wchar -fno-builtin -fno-stack-protector \
	-mno-implicit-float -O2 -Wall -Wextra -Wno-unused-parameter

all: framebuffer.efi loader.efi

%.efi: %.c efi.h
	clang $(CFLAGS) -c $< -o $*.o
	$(LLD_LINK) /nologo /Brepro /nodefaultlib /dll /entry:efi_main /subsystem:$(SUBSYSTEM) /out:$@ $*.o
	rm -f $*.o $*.lib

framebuffer.efi: SUBSYSTEM = efi_boot_service_driver
loader.efi: SUBSYSTEM = efi_application

clean:
	rm -f *.efi *.o *.lib

.PHONY: all clean
