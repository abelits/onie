#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
#
# makefile fragment that defines the creation of onie images
#

SYSROOT_CPIO_XZ		= $(IMAGEDIR)/$(MACHINE_PREFIX).initrd
SYSROOT_CPIO_XZ_PXE	= $(IMAGEDIR)/$(MACHINE_PREFIX).initrd-pxe
KERNEL_IMAGE		= $(IMAGEDIR)/$(MACHINE_PREFIX).vmlinuz


PHONY += images-pxe images-pxe-clean

images-pxe: $(SYSROOT_CPIO_XZ_PXE)

$(SYSROOT_CPIO_XZ_PXE): $(KERNEL_IMAGE) $(SYSROOT_CPIO_XZ)
	$(Q) echo "==== Create $(MACHINE_PREFIX) PXE ONIE image ===="
	$(Q) cd $(IMAGEDIR) && \
	mkdir self-installer && \
	cp $(MACHINE_PREFIX).vmlinuz self-installer/onie.vmlinuz && \
	cp $(MACHINE_PREFIX).initrd self-installer/onie.initrd && \
	cp $(MACHINEDIR)/self-installer/format-installer.sh self-installer && \
	xzcat $(MACHINE_PREFIX).initrd > $(MACHINE_PREFIX).initrd-pxe.tmp && \
	find self-installer | fakeroot cpio --create -H newc --append --file $(MACHINE_PREFIX).initrd-pxe.tmp && \
	xz --compress --force --check=crc32 --stdout -8 $(MACHINE_PREFIX).initrd-pxe.tmp > $(MACHINE_PREFIX).initrd-pxe && \
	rm -r $(MACHINE_PREFIX).initrd-pxe.tmp self-installer

USERSPACE_CLEAN += images-pxe-clean

images-pxe-clean:
	$(Q) rm -f $(SYSROOT_CPIO_XZ_PXE)
	$(Q) echo "=== Finished making $@ for $(PLATFORM)"

#
################################################################################
#
# Local Variables:
# mode: makefile-gmake
# End:
