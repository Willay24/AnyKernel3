### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Adapted for Nothing Phone 1 (Spacewar) / LineageOS, based on functions from Pzqqt's Marble-Bouquet script

### AnyKernel setup
# begin properties
properties() { '
kernel.string=Spacewar by @Biased69-KittenLover
kernel.revision=5.4
kernel.made=Biased69-Kitty
anykernel3.made=osm0sis @ xda-developers
kernel.compiler=Slim LLVM 23.1.0
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=Spacewar
device.name2=spacewar
device.name3=
device.name4=
device.name5=
supported.versions=11.0-17.0
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

# shell variables
block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto
no_magisk_check=true

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh

split_boot

########## FLASH BOOT & DTBO START ##########

KEYCODE_UP=42
KEYCODE_DOWN=41

sha1() { ${bin}/magiskboot sha1 "$1"; }

random_strings() {
	local len=$1

	cat /dev/urandom | tr -dc 'a-zA-Z' | head -c $len
}

get_keycheck_result() {
	# Default behavior:
	# - press Vol+: return true (0)
	# - press Vol-: return false (1)

	local rc_1 rc_2

	while true; do
		# The first execution responds to the button press event,
		# the second execution responds to the button release event.
		${bin}/keycheck; rc_1=$?
		${bin}/keycheck; rc_2=$?
		[ "$rc_1" == "$rc_2" ] || continue
		case "$rc_2" in
			"$KEYCODE_UP") return 0;;
			"$KEYCODE_DOWN") return 1;;
		esac
	done
}

keycode_select() {
	local r_keycode

	ui_print " "
	while [ $# != 0 ]; do
		ui_print "# $1"
		shift
	done
	ui_print "#"
	ui_print "# Press Vol+ to select YES, Vol- to select NO"
	get_keycheck_result
	r_keycode=$?
	ui_print "#"
	if [ "$r_keycode" -eq "0" ]; then
		ui_print "- You chose: YES"
	else
		ui_print "- You chose: NO"
	fi
	ui_print " "
	return $r_keycode
}

# Sanity checks
[ -f ${home}/Image ] || abort "! Cannot find ${home}/Image!"
[ -f ${home}/dtbo.img ] || abort "! Cannot find ${home}/dtbo.img!"
ui_print "- Kernel version:"
ui_print "  $(strings ${home}/Image 2>/dev/null | grep -E -m1 'Linux version.*#')"

# Check snapshot status (avoid flashing in the middle of an OTA update)
# Technical details: https://blog.xzr.moe/archives/30/
${bin}/snapshotupdater_static dump &>/dev/null
rc=$?
if [ "$rc" != 0 ]; then
	ui_print " "
	ui_print "! Failed to get snapshot status rc=$rc."
	if ${BOOTMODE}; then
		ui_print "! If an OTA update is being installed, wait for it"
		ui_print "! to finish and reboot before flashing this kernel."
	fi
	abort "! Aborting..."
fi
snapshot_status=$(${bin}/snapshotupdater_static dump 2>/dev/null | grep '^Update state:' | awk '{print $3}')
ui_print "- Current snapshot status: $snapshot_status"
if [ "$snapshot_status" != "none" ]; then
	ui_print " "
	ui_print "! An OTA update appears to be in progress."
	ui_print "! Reboot to complete it before flashing this kernel."
	abort "! Aborting..."
fi
unset rc snapshot_status

# Staging unmodified partition image for rollback
mkdir -p ${home}/_orig
cp ${home}/boot.img ${home}/_orig/boot.img

# Backup stock kernel + dtbo (+ vendor_boot) to a restore zip on /sdcard
if keycode_select \
    "Create a backup package of the current kernel?" \
    " " \
    "This will generate a flashable restore zip on /sdcard" \
    "containing your current kernel and dtbo image."; then

	ui_print "- Creating backup package..."
	ui_print "  Do not reboot until it is finished!"

	backup_package=/sdcard/Spacewar-restore-kernel-$(date +"%Y%m%d-%H%M%S").zip

	${bin}/7za a -tzip -bd $backup_package \
		${home}/META-INF ${bin} ${home}/LICENSE ${home}/_restore_anykernel.sh \
		${split_img}/kernel \
		/dev/block/bootdevice/by-name/dtbo${slot} \
		/dev/block/bootdevice/by-name/vendor_boot${slot}
	${bin}/7za rn -bd $backup_package kernel Image
	${bin}/7za rn -bd $backup_package _restore_anykernel.sh anykernel.sh
	${bin}/7za rn -bd $backup_package dtbo${slot} dtbo.img
	${bin}/7za rn -bd $backup_package vendor_boot${slot} vendor_boot.img
	# Remove binaries the restore zip does not need
	${bin}/7za d  -bd $backup_package \
		tools/keycheck tools/fec tools/unpackbootimg tools/mkbootimg tools/magiskpolicy
	sync

	ui_print " "
	ui_print "- Backup package created:"
	ui_print "  $backup_package"
	ui_print "- You can flash it later to restore the current kernel."
	ui_print " "
	touch ${home}/do_backup_flag

	if ! $BOOTMODE && [ ! -d /twres ]; then
		ui_print "============================================================"
		ui_print "! Warning: Please transfer the backup file just generated to"
		ui_print "! another device via ADB, as it will be lost after reboot!"
		ui_print "============================================================"
		ui_print " "
		sleep 3
	fi

	unset backup_package
fi

# Last chance to bail out
if ! keycode_select \
    "Ready to flash the new kernel now?" \
    " " \
    "Vol+ = flash and reboot, Vol- = abort"; then
	abort "! Flashing aborted by user."
fi

write_boot # flashes boot; dtbo.img is flashed automatically via flash_generic dtbo

# Patch vbmeta (disable verification on all vbmeta partitions)
ui_print " "
for vbmeta_blk in /dev/block/by-name/vbmeta*; do
	ui_print "- Patching $(basename $vbmeta_blk) ..."
	${bin}/vbmeta-disable-verification $vbmeta_blk || {
		ui_print "! Failed to patch ${vbmeta_blk}!"
		ui_print "! You may need to disable avb verification manually."
	}
done

# Remove files no longer needed to avoid flashing again
rm -f ${home}/Image
rm -f ${home}/dtbo.img
rm -f ${home}/boot.img
rm -f ${home}/boot-new.img

########## FLASH BOOT & DTBO END ##########

## end boot install