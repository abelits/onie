################################################################################
ONIE for x86 – changes made for IM platform and future direction of development.
################################################################################

1. Background.
==============

ONIE (Open Network Install Environment) is a set of software and firmware intended to be used for installing, un-installing and updating software on network switches, manually or automatically, over the network. It is implemented as a small Linux system, capable of running on a ramdisk, so it can be seen as a minimal, specialized Linux distribution, with a set of tools and custom scripts (all implemented in Bourne shell) designed for the purpose of networked software installation.

Originally ONIE was developed on PPC platform, and currently is being ported to other CPU architectures and hardware platforms used in network switches. Among other target platforms there are the OCP (Open Compute Project) network switches. At the moment when Interface Masters (IM) developers became involved, minimal ports to x86_64 platform in general, and to IM hardware in particular, were already produced by the original developers from Cumulus Networks.

The port to IM hardware, though already capable of running on the target device, had to be adapted to be compatible with the rest of the software for that platform (or, to be more precise, ONIE and installable software had to be adapted to work with each other), to support peculiarities of the platform hardware, and to fit into the IM production procedures.

2. Peculiarities of IM hardware.
================================

IM hardware contains x86-based CPU boards that consist of a carrier board with IM-specific connectors and a COM Express module, a small motherboard built around an Intel or AMD CPU and chipset. The module contains CPU, chipset, DRAM, onboard Ethernet, and bus controllers. Carrier board has power circuitry, SuperI/O chip with traditional PC interfaces, CPLD responsible for communication with IM-specific serial bus, PCIe connectors that allow PCIe endpoints on the switch board (currently Broadcom switch ASICs) to be connected to the PCIe bus of the COM Express module, and a mSATA SSD used as the boot device.

For debugging and development purposes, carrier board has VGA connector, serial console (TTL levels) header, and two USB2 ports (inverted mini-USB), however none of those ports, save for the serial console, are accessible while the CPU module is inside the switch enclosure. Even when the enclosure is opened (what would compromise the cooling of CPU, switch ASIC, PHYs and other chips if special precautions are not taken), the connectors are inaccessible inside the densely packed case. In particular, fan controller board with four 40mm fans is placed against the back of the CPU board, blocking VGA and USB connectors facing in that direction.

Even if the design was changed to allow routing one of the USB connectors to a jack on the front or rear panel, there is insufficient space on either of those panels to place such a jack. Front panel is filled with network ports and would be covered with cables when the switch is in use, rear panel has four 40mm fans, two hot-pluggable power supplies, leaving only enough space for two vertically stacked RJ-45 ports – management port (Gigabit Ethernet) and a serial console (RS-232 levels). This placed the developers into a unique situation when otherwise traditional x86-based computer has no storage devices physically under control of the user.

Being a general-purpose x86-based board, COM Express modules are interchangeable, and IM intends to build multiple CPU boards, likely sharing the same carrier board but using various CPUs from Intel and AMD.

Higher performance and core count come with increased power consumption and heat production, while most traditional switch applications do not impose significant performance requirements on the control CPU. On the other hand, there is an emerging class of applications that heavily rely on switch CPU performing large amount of processing, and developers have found that x86-based switch is a good platform for self-hosted firmware development, so for those purposes performance is important  even if it comes with additional costs. This means, just using the parts with highest performance available within a given price range is not a good solution like it usually is for servers, and support for a wide variety of CPUs and boards is a real requirement for this platform. Additionally, x86 CPUs and boards often go in and out of production, and it would be nice to produce a future-proof design that won't have to be re-adjusted on trivial changes, and would not have to be maintained with special images for product versions that use obsolete parts no longer available for the future developers but still in use in the field.

The above mentioned peculiarities dictate the following requirements for installers used on IM hardware:

1. Installer must be functional in a situation when user has no access to storage, USB or VGA ports. Serial console and Gigabit Ethernet should be sufficient to perform all installation, maintenance and recovery operations.
2. Software should be usable on a hardware that varies and changes over time, within the limits expected from a x86 COM Express boards, what in its turn is similar to variation between x86-based servers.

3. Peculiarities and requirements specific to x86 platform in general.
======================================================================

3.1. x86 switch and x86 server – similarities and differences.
==============================================================

Though the above mentioned list is a necessity for IM hardware support, it is useful on all x86 hardware platforms. However the distinction from the embedded-style switches that are commonly used now, goes much deeper than that. x86-based switch for the purpose of software management is almost indistinguishable from a small server – most of differences for the system administrator are in things switch definitely won't be used for – such as running I/O-heavy applications, using remote storage, etc. And even those may be reduced in the future, when it may become necessary to combine communication (networking, connection management, load balancing, failover) and state storage/propagation (storage, storage management, database servers) within the same device controlled by a single locally running instance of software.

Ideally, management and software installation for switches should be similar to one for the servers, and possibly usable for the servers, however with greater expectation of autonomy of the device, and less reliance on network boot and storage. Switches have non-redundant management interfaces, and they are supposed to be connected to a secure network with minimal amount of potential security hazards, so failure of this single management network should not bring down the switch, prevent it from booting, or place any obstacles for emergency management over the serial console.
While both servers and switches can be organized in a redundant high-availability configuration, it is easy to have a great number of "throwaway servers" that may hang as a result of a failure in their fast but non-redundant connection to remote storage, only to be replaced with their neighbors in the cluster, but it's hard to make something equally redundant out of the switches – even if all servers will have two network ports for redundancy connected to separate switches, a failure of two fully populated 48-port switches can easily mean 48 servers offline no matter how well-designed is the rest of the network fabric. If both switches relied on a constant presence of a single management network, that would be a likely, and frightening scenario.

3.2. ONIE, Linux distributions and bootloader configuration.
============================================================

Back to the similarities between switches and servers, one important detail is that x86 switches that will be installed with ONIE, will run a general-purpose Linux distribution, with package manager already managing both software on the root filesystem, and the bootloader. If ONIE will install its bootloader and OS will insist on installing its own, two outcomes may happen:

1. OS installer or bootloader manager will believe that hard drive has no bootloader at all, and install its own, only aware of boot options known to the software managed by OS package manager – thus locking ONIE out.
2. OS installer will not instal a bootloader, or install it in the "wrong" location, so ONIE-managed bootloader will remain active. Later package manager will install a new kernel or add another boot option, while ONIE-managed bootloader will still try to boot the system using the old kernel's name in its configuration. Either, the wrong kernel will load, or it will not be possible to boot the system without propagating the changes into ONIE-managed configuration.

This can be avoided by making ONIE aware of the bootloader and configuration, and modifying OS procedure of updating its kernel, however in pre-existing implementation of the x86 port, there were significant assumptions about how it is supposed to happen, and as far as we know, it would not seamlessly integrate into Debian (what is currently used on the switches with Ubuntu or Debian OS) or Red Hat package management.

ONIE itself also becomes an odd component in the set of software on the switch. Modern Linux distributions manage everything with a package manager, including the bootloader that boots them and non-Linux bootable software such as memtest86. Bootloader update can be performed through the regular package management with no requirement for rebooting the system. ONIE, on the other hand, can update itself (requiring a reboot) but can not be updated by the package manager, or at least provides no mechanism for doing so. Considering that installable part of ONIE code is just two files, this limitation seems to be artificial – it would make sense to at least provide the packaging support at the level of memtest86. ONIE self-update procedure makes an assumption about partitions layout (hardcoded into ONIE), and would try to re-create it if it was changed – possibly rendering unbootable the OS already installed on the switch and destroying locally stored configuration.

It would be better if there was a safe procedure to install or update ONIE from Linux (ideally, through its package manager), and ONIE installed in this manner would be still able to uninstall the original Linux system it was installed under, remain active, install another one, and yet become integrated into it, and accept updates from the new system.

3.3. Lack of sufficiently protected bootloader.
===============================================

There is also another problem that exists on x86 platform – there is no protected bootloader that would be invulnerable to being erased or reconfigured into a completely unbootable state due to the user's error. It is possible that the bootloader (installed by OS or ONIE) will be erased, thus "bricking" the device until its storage medium is replaced.
For IM hardware it means opening the case, removing CPU board, taking out the mSATA SSD (attached on the bottom), connecting it to a computer with mSATA interface (that is very uncommon except for internal connectors on laptops, and is not hot-pluggable, so it will require a reboot), install ONIE on it (what would risk erasing the hard drive of that computer if the ONIE installer was used), then re-assemble the switch. On top of this procedure being difficult and cumbersome, it also can not be supported by IM because it involves opening the case and disassembling the hardware, something that is not supposed to be performed by the user in the field.

Other manufacturers may have more acceptable procedures (removable storage, accessible USB or other ports for booting the recovery media), however it would be nice to have a common recovery mechanism that would require absolutely least amount of effort and, ideally, no physical contact with the switch.

3.4. ONIE and PXE.
==================

The traditional "last-resort recovery" mechanism on x86 is PXE, and it is well suited for this purpose. While it's true that using PXE as the only or primary boot mechanism for the switches makes the network less reliable and secure, using it for recovery is well justified. PXE can be set up as the fallback boot method if booting from the primary boot device fails, or (what would be necessary if bootloader is damaged and hangs in the middle of the boot process) selected from the serial console of the device that needs recovery. Switches' consoles are usually managed through terminal servers, so this operation by itself will be simple and reliable.

There is, however, a problem – ONIE is not designed to work on a system where storage is inaccessible, broken or does not have ONIE-specific partitions, the assumption is that ONIE is booted from the primary boot device, so its files have to be there somewhere. PXE-ified ONIE image would have to be usable for at least two operations, manual recovery and full ONIE re-installation, without having any usable storage.

Though outside of the original ONIE functionality, there is another possibility that opens when ONIE can be loaded over PXE and run as a self-contained environment – ONIE can install systems without being installed on the host itself. If ONIE will be able to run completely independently from the content of any storage device, it will be possible to use it for initial installation of software managed entirely from a provisioning server, however ONIE itself may be completely absent from the final installed configuration, or final installed image will contain ONIE that is completely unrelated to one that was used for installation. As with the recovery procedure, it is sufficient to have hard drive empty, and set as the first choice of the boot device, with PXE as a fallback. A switch will boot, default boot device will be un-bootable (no MBR or bootloader), PXE will boot ONIE that will discover the OS image installer and install it on the system, then reboot. At that point OS is installed (with partition table, MBR and bootloader), so OS will always boot from the hard drive unless hard drive is rendered un-bootable again, or boot priority is modified through the BIOS configuration interface. Until then, the switch can be autonomous and not dependent on provisioning server being available in any way – at worst, if DHCP is used to configure management interface, switch will not get DHCP-managed IP address but will still work, be available for management over the serial console, and possibly allocate management interface's IP address through a fallback mechanism such as zeroconf.

This mechanism is usable not just for switches but also for servers, so it may open the possibility for wider use of ONIE in data centers (and with it, wider participation of developers).

4. Changes in IM platform implementation.
=========================================

The changes currently made in im_devel branch include both modifications intended to specifically accommodate IM platform, and changes that are intended for more broad support of x86-based devices. Some of those modifications were made to use specific formats that are currently in use by IM, and no backward compatibility with existing x86 support, however the intention is to make the implementation flexible, automatically detect either of those two (and possibly a multitude of others) storage layouts, and accommodate them through additional variables and conditionals in the scripts.

4.1 SSD device identification.
==============================

The original procedure that identifies SSD as the block device on a specific controller identified by its position on the PCI bus, is too specific and would not work with other, otherwise identical COM Express modules. It was replaced with more universal definition as the first block device that is handled as an equivalent of a SCSI hard drive (sd), and that is attached to an AHCI controller.

This will always identify the SSD as long as it is the only SATA drive on the system, and will reliably exclude all other storage devices – at least until there will be more directly connected SATA drives. In the case this definition will become unusable on some new models, it will be necessary to add more definitions, and use dmidecode utility to distinguish be
