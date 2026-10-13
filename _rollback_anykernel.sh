### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Rollback script: flashes back the _orig boot/dtbo images staged during install
## (run by update-binary when install fails after rollback_if_abort_flag was set)

### AnyKernel setup
# global properties
properties() { '
kernel.string=Rollback kernel
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
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install

## boot shell variables
block=boot
is_slot_device=1
ramdisk_compression=auto
patch_vbmeta_flag=auto

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
no_block_display=true
. tools/ak3-core.sh
unset no_block_display

[ -n "$AKHOME" ] || AKHOME=$home

ui_print " "
ui_print "! Flashing failed, restoring the original boot/dtbo images..."

for partition in boot dtbo; do
	if [ -f ${AKHOME}/_orig/${partition}.img ]; then
		mv -f ${AKHOME}/_orig/${partition}.img ${AKHOME}/${partition}.img
		rm -f ${AKHOME}/${partition}_flashed
		flash_generic ${partition}
	fi
done

## end boot install