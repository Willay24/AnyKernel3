### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

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
is_slot_device=1
ramdisk_compression=auto
patch_vbmeta_flag=auto

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh

########## OPTIONS ##########

# 1 = abort when the OTA/snapshot state cannot be read at all.
# 0 = warn and continue. This package only writes boot (+ dtbo), never a
#     logical partition, so an unreadable state is not dangerous.
STRICT_SNAPSHOT_CHECK=0

# 1 = ask with the volume keys, 0 = skip the question (backup: yes, confirm: yes)
ASK_BACKUP=1
ASK_CONFIRM=1

########## COMPATIBILITY / HELPERS ##########

# Variable names differ between ak3-core versions (home/bin vs AKHOME/BIN)
[ -n "$AKHOME" ] || AKHOME=$home
[ -n "$BIN" ] || BIN=$bin

KEYCODE_UP=42
KEYCODE_DOWN=41

# update-binary's functions are not visible in this child shell, redefine
is_mounted() { mount | grep -q " $1 "; }

# update-binary does not export BOOTMODE; detect it here when it is missing
if [ -z "$BOOTMODE" ]; then
	BOOTMODE=false
	{ ps -A 2>/dev/null || ps; } | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
fi

# Unpack a payload archive built with the workflow's pack_7z option.
# Raw (uncompressed) packages simply skip this.
unpack_7z() {
	local archive=$1 dest=$2

	[ -f "$archive" ] || return 0
	[ -x "${BIN}/7za" ] || abort "! tools/7za not found, cannot unpack $(basename $archive)!"
	mkdir -p "$dest"
	${BIN}/7za x -y -bd -o"$dest" "$archive" >/dev/null || \
		abort "! Failed to unpack $(basename $archive)!"
	rm -f "$archive"
}

get_keycheck_result() {
	# - press Vol+: return true (0)
	# - press Vol-: return false (1)
	local rc_1 rc_2

	while true; do
		# The first execution responds to the button press event,
		# the second execution responds to the button release event.
		${BIN}/keycheck; rc_1=$?
		${BIN}/keycheck; rc_2=$?
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

	# Without keycheck the loop above would spin forever, so fall back to YES
	if [ ! -x "${BIN}/keycheck" ]; then
		ui_print "# (keycheck not found, defaulting to YES)"
		ui_print " "
		return 0
	fi

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

# Sets: snapshot_state (empty = unknown) and snapshot_err (diagnostic file)
get_snapshot_state() {
	local mounted_here=false

	snapshot_state=
	snapshot_err=${AKHOME}/snapshot_dump.err
	: > $snapshot_err

	# /metadata is not always mounted when flashing from recovery
	if ! is_mounted /metadata; then
		mount /metadata 2>>$snapshot_err || \
			mount -o ro /dev/block/bootdevice/by-name/metadata /metadata 2>>$snapshot_err
		is_mounted /metadata && mounted_here=true
	fi

	# 1) snapshotupdater_static: read the state line from stdout and ignore the
	#    exit code, only the state itself matters here.
	if [ -x "${BIN}/snapshotupdater_static" ]; then
		"${BIN}/snapshotupdater_static" dump >${AKHOME}/snapshot_dump.out 2>>$snapshot_err
		echo "snapshotupdater_static dump rc=$?" >>$snapshot_err
		snapshot_state=$(awk '/^Update state:/{print $3; exit}' ${AKHOME}/snapshot_dump.out 2>/dev/null)
	fi

	# 2) fallback: the ROM's own bootctl (talks to the boot HAL)
	if [ -z "$snapshot_state" ] && [ -x /system/bin/bootctl ]; then
		snapshot_state=$(/system/bin/bootctl get-snapshot-merge-status 2>>$snapshot_err | head -n1 | tr 'A-Z' 'a-z' | tr -d ' \r')
	fi

	# Only accept something that looks like a state name
	case "$snapshot_state" in
		*[!a-z-]*) snapshot_state=;;
	esac

	$mounted_here && umount /metadata 2>/dev/null
	return 0
}

########## UNPACK PAYLOAD (pack_7z builds) ##########

unpack_7z ${AKHOME}/Image.7z ${AKHOME}
unpack_7z ${AKHOME}/_dtb.7z  ${AKHOME}     # carries dtbo.img (and dtb/dtb.img on older builds)

# Boot/vendor_boot are header v3: the dtb lives in vendor_boot, which this
# package does not touch (all custom DT changes are in the dtbo overlay).
# Make sure stray dtb files can never be injected into the boot image.
rm -f ${AKHOME}/dtb ${AKHOME}/dtb.img

########## BOOT IMAGE ##########

split_boot # the ramdisk is not modified, so skip unpacking it

[ -n "$SPLITIMG" ] || SPLITIMG=$split_img
[ -n "$SLOT" ] || SLOT=$slot
[ -n "$SLOT" ] || SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
[ -n "$SLOT" ] || SLOT=$(grep -o 'androidboot.slot_suffix=[^ ]*' /proc/cmdline 2>/dev/null | cut -d= -f2)

########## PRE-FLIGHT CHECKS ##########

[ -f ${AKHOME}/Image ] || abort "! Cannot find ${AKHOME}/Image!"
have_dtbo=false
[ -f ${AKHOME}/dtbo.img ] && have_dtbo=true

ui_print "- Kernel version:"
ui_print "  $(strings ${AKHOME}/Image 2>/dev/null | grep -E -m1 'Linux version.*#')"

# This ROM ships a vendor_dlkm partition: its modules are not modified here
if ls /dev/block/mapper/vendor_dlkm* >/dev/null 2>&1; then
	ui_print "- Note: vendor_dlkm detected, its modules are not modified by this package."
fi

# Check snapshot status (avoid flashing in the middle of an OTA update).
# Technical details: https://blog.xzr.moe/archives/30/
if [ "$(getprop ro.virtual_ab.enabled 2>/dev/null)" == "true" ]; then
	get_snapshot_state
	if [ -z "$snapshot_state" ]; then
		ui_print " "
		ui_print "! Could not read the OTA snapshot status. Details:"
		head -n 4 $snapshot_err | while read -r line; do
			ui_print "  $line"
		done
		if [ "$STRICT_SNAPSHOT_CHECK" == 1 ]; then
			ui_print "! If an OTA update is being installed, wait for it"
			ui_print "! to finish and reboot before flashing this kernel."
			abort "! Aborting..."
		fi
		ui_print "- Continuing anyway (only boot/dtbo are written)."
		ui_print " "
	elif [ "$snapshot_state" != "none" ]; then
		ui_print " "
		ui_print "- Current snapshot status: $snapshot_state"
		ui_print "! An OTA update appears to be in progress."
		ui_print "! Reboot to complete it before flashing this kernel."
		abort "! Aborting..."
	else
		ui_print "- Current snapshot status: none"
	fi
fi

# Staging unmodified partition images for backup / rollback
mkdir -p ${AKHOME}/_orig
if [ -f ${AKHOME}/boot.img ]; then
	cp ${AKHOME}/boot.img ${AKHOME}/_orig/boot.img
else
	dd if=$block of=${AKHOME}/_orig/boot.img 2>/dev/null
fi
[ -s ${AKHOME}/_orig/boot.img ] || abort "! Failed to stage the stock boot image!"
if $have_dtbo; then
	dd if=/dev/block/bootdevice/by-name/dtbo${SLOT} of=${AKHOME}/_orig/dtbo.img 2>/dev/null
	[ -s ${AKHOME}/_orig/dtbo.img ] || rm -f ${AKHOME}/_orig/dtbo.img  # never keep a truncated copy
fi

########## BACKUP OF THE CURRENT KERNEL ##########

# Backup stock kernel + dtbo to a restore zip.
# (vendor_boot is not modified by this package, so it is not backed up:
#  restoring an old vendor_boot after a ROM update could cause a bootloop)
do_backup=true
if [ "$ASK_BACKUP" == 1 ]; then
	keycode_select \
	    "Create a backup package of the current kernel?" \
	    " " \
	    "This will generate a flashable restore zip on /sdcard" \
	    "containing your current kernel and dtbo image." || do_backup=false
fi

if $do_backup && [ ! -x "${BIN}/7za" ]; then
	ui_print "! tools/7za not found, skipping the backup package."
	do_backup=false
fi

backup_dir=
if $do_backup; then
	for d in /sdcard /data/media/0; do
		if [ -d "$d" ] && [ -w "$d" ]; then backup_dir=$d; break; fi
	done
	if [ -z "$backup_dir" ]; then
		ui_print "! No writable storage found (is /data decrypted?), skipping the backup package."
		do_backup=false
	fi
fi

if $do_backup; then
	ui_print "- Creating backup package..."
	ui_print "  Do not reboot until it is finished!"

	rom_ver=$(file_getprop /system/build.prop ro.build.version.incremental)
	[ "$rom_ver" ] || rom_ver=unknown
	rom_ver=$(echo "$rom_ver" | tr -c 'A-Za-z0-9._\n-' '_')
	backup_package=${backup_dir}/Spacewar-restore-kernel-${rom_ver}-$(date +"%Y%m%d-%H%M%S").zip
	backup_license=
	[ -f ${AKHOME}/LICENSE ] && backup_license=${AKHOME}/LICENSE
	backup_banner=
	[ -f ${AKHOME}/banner ] && backup_banner=${AKHOME}/banner
	backup_dtbo=
	[ -f ${AKHOME}/_orig/dtbo.img ] && backup_dtbo=${AKHOME}/_orig/dtbo.img

	${BIN}/7za a -tzip -bd $backup_package \
		${AKHOME}/META-INF ${BIN} $backup_license $backup_banner ${AKHOME}/_restore_anykernel.sh \
		${SPLITIMG}/kernel $backup_dtbo
	${BIN}/7za rn -bd $backup_package kernel Image
	${BIN}/7za rn -bd $backup_package _restore_anykernel.sh anykernel.sh
	# Remove binaries the restore zip does not need
	${BIN}/7za d  -bd $backup_package \
		tools/7za tools/keycheck tools/snapshotupdater_static tools/vbmeta-disable-verification \
		tools/e2fsck tools/resize2fs tools/extract.erofs tools/mkfs.erofs \
		tools/fdtget tools/fdtput tools/dtp tools/kmod tools/hpatchz
	sync

	if [ -s "$backup_package" ]; then
		ui_print " "
		ui_print "- Backup package created:"
		ui_print "  $backup_package"
		ui_print "- You can flash it later to restore the current kernel."
		ui_print " "
		touch ${AKHOME}/do_backup_flag

		if ! $BOOTMODE && [ ! -d /twres ]; then
			ui_print "============================================================"
			ui_print "! Warning: Please transfer the backup file just generated to"
			ui_print "! another device via ADB, as it will be lost after reboot!"
			ui_print "============================================================"
			ui_print " "
			sleep 3
		fi
	else
		ui_print "! Backup package could not be created, continuing without it."
	fi

	unset rom_ver backup_package backup_license backup_banner backup_dtbo
fi
unset do_backup backup_dir

########## LAST CHANCE TO BAIL OUT ##########

if [ "$ASK_CONFIRM" == 1 ]; then
	if ! keycode_select \
	    "Ready to flash the new kernel now?" \
	    " " \
	    "Vol+ = flash, Vol- = abort"; then
		abort "! Flashing aborted by user."
	fi
fi

########## FLASH ##########

# From here on a failed flash is rolled back by update-binary
# (it runs _rollback_anykernel.sh when this flag exists).
touch ${AKHOME}/rollback_if_abort_flag

flash_boot                # boot (ramdisk untouched, Magisk/KSU patching handled by the core)
flash_generic dtbo        # no-op when the zip has no dtbo.img

# The flash itself finished: later steps must not trigger a rollback.
rm -f ${AKHOME}/rollback_if_abort_flag

########## PATCH VBMETA ##########

ui_print " "
if [ -x "${BIN}/vbmeta-disable-verification" ]; then
	for vbmeta_blk in /dev/block/by-name/vbmeta*; do
		[ -e "$vbmeta_blk" ] || continue
		ui_print "- Patching $(basename $vbmeta_blk) ..."
		${BIN}/vbmeta-disable-verification $vbmeta_blk || {
			ui_print "! Failed to patch ${vbmeta_blk}!"
			ui_print "! You may need to disable avb verification manually."
		}
	done
else
	ui_print "! tools/vbmeta-disable-verification not found, skipping vbmeta patch."
fi

## end boot install