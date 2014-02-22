#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
#
# This is a makefile fragment that defines the build of gptfdisk
#

PARTED_VERSION			= 3.1
PARTED_TARBALL			= parted-$(PARTED_VERSION).tar.xz
PARTED_TARBALL_URLS		+= http://ftp.gnu.org/gnu/parted/
PARTED_BUILD_DIR		= $(MBUILDDIR)/parted
PARTED_DIR			= $(PARTED_BUILD_DIR)/parted-$(PARTED_VERSION)

PARTED_SRCPATCHDIR		= $(PATCHDIR)/parted
PARTED_DOWNLOAD_STAMP		= $(DOWNLOADDIR)/parted-download
PARTED_SOURCE_STAMP		= $(STAMPDIR)/parted-source
PARTED_PATCH_STAMP		= $(STAMPDIR)/parted-patch
PARTED_BUILD_STAMP		= $(STAMPDIR)/parted-build
PARTED_INSTALL_STAMP		= $(STAMPDIR)/parted-install
PARTED_STAMP			= $(PARTED_SOURCE_STAMP) \
				  $(PARTED_PATCH_STAMP) \
				  $(PARTED_BUILD_STAMP) \
				  $(PARTED_INSTALL_STAMP)

PARTED_PROGRAMS		= parted/.libs/parted
PARTED_LIBS		= libparted/.libs/libparted.so \
			libparted/.libs/libparted.so.2 \
			libparted/.libs/libparted.so.2.0.0

PHONY += parted parted-download parted-source parted-patch \
	parted-build parted-install parted-clean parted-download-clean

parted: $(PARTED_STAMP)

DOWNLOAD += $(PARTED_DOWNLOAD_STAMP)
parted-download: $(PARTED_DOWNLOAD_STAMP)
$(PARTED_DOWNLOAD_STAMP): $(PROJECT_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Getting upstream parted ===="
	$(Q) $(SCRIPTDIR)/fetch-package $(DOWNLOADDIR) $(UPSTREAMDIR) \
		$(PARTED_TARBALL) $(PARTED_TARBALL_URLS)
	$(Q) touch $@

SOURCE += $(PARTED_SOURCE_STAMP)
parted-source: $(PARTED_SOURCE_STAMP)
$(PARTED_SOURCE_STAMP): $(TREE_STAMP) | $(PARTED_DOWNLOAD_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Extracting upstream parted ===="
	$(Q) $(SCRIPTDIR)/extract-package $(PARTED_BUILD_DIR) $(DOWNLOADDIR)/$(PARTED_TARBALL)
	$(Q) touch $@

parted-patch: $(PARTED_PATCH_STAMP)
$(PARTED_PATCH_STAMP): $(PARTED_SRCPATCHDIR)/* $(PARTED_SOURCE_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Patching parted ===="
	$(Q) $(SCRIPTDIR)/apply-patch-series $(PARTED_SRCPATCHDIR)/series $(PARTED_DIR)
	$(Q) touch $@

ifndef MAKE_CLEAN
PARTED_NEW_FILES = $(shell test -d $(PARTED_DIR) && test -f $(PARTED_BUILD_STAMP) && \
	              find -L $(PARTED_DIR) -newer $(PARTED_BUILD_STAMP) -type f -print -quit)
endif

parted-build: $(PARTED_BUILD_STAMP)
$(PARTED_BUILD_STAMP): $(PARTED_PATCH_STAMP) $(PARTED_NEW_FILES)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "====  Building parted-$(PARTED_VERSION) ===="
	$(Q) cd $(PARTED_DIR) && PATH='$(CROSSBIN):$(PATH)'	\
		$(PARTED_DIR)/configure				\
		--without-readline				\
		--disable-device-mapper 			\
                --prefix=$(DEV_SYSROOT)/usr                     \
                --host=$(TARGET)                                \
                CC=$(CROSSPREFIX)gcc                            \
                CFLAGS="$(ONIE_CFLAGS)"
	$(Q) PATH='$(CROSSBIN):$(PATH)'	$(MAKE) -C $(PARTED_DIR) \
		all CROSS_COMPILE=$(CROSSPREFIX) \
		CXXFLAGS="$(ONIE_CXXFLAGS)" LDFLAGS="$(ONIE_LDFLAGS)"
	$(Q) touch $@

parted-install: $(PARTED_INSTALL_STAMP)
$(PARTED_INSTALL_STAMP): $(SYSROOT_INIT_STAMP) $(PARTED_BUILD_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Installing parted programs in $(SYSROOTDIR) ===="
	$(Q) for file in $(PARTED_PROGRAMS); do \
		cp -av $(PARTED_DIR)/$$file $(SYSROOTDIR)/usr/bin ; \
	     done
	$(Q) for file in $(PARTED_LIBS) ; do \
		cp -av $(PARTED_DIR)/$$file $(SYSROOTDIR)/usr/lib/ ; \
	done
	$(Q) touch $@

USERSPACE_CLEAN += parted-clean
parted-clean:
	$(Q) rm -rf $(PARTED_BUILD_DIR)
	$(Q) rm -f $(PARTED_STAMP)
	$(Q) echo "=== Finished making $@ for $(PLATFORM)"

DOWNLOAD_CLEAN += parted-download-clean
parted-download-clean:
	$(Q) rm -f $(PARTED_DOWNLOAD_STAMP) $(DOWNLOADDIR)/$(PARTED_TARBALL)

#-------------------------------------------------------------------------------
#
# Local Variables:
# mode: makefile-gmake
# End:
