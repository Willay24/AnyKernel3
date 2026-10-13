### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Restore script: flashes back the backed-up stock kernel (Image) and dtbo.img
## (this file is packed into the backup zip and renamed to anykernel.sh)

### AnyKernel setup
# global properties
properties() { '
kernel.string=Restore kernel
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
. tools/ak3-core.sh

[ -n "$AKHOME" ] || AKHOME=$home

[ -f ${AKHOME}/Image ] || abort "! Cannot find ${AKHOME}/Image in the backup package!"

split_boot # keep the ROM's current ramdisk, only the kernel is swapped

flash_boot
flash_generic dtbo # no-op when the backup has no dtbo.img

## end boot install