### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Restore script: flashes back the backed-up stock kernel & dtbo

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
no_magisk_check=true

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh

dump_boot # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

write_boot # use flash_boot to skip ramdisk repack; also flashes dtbo.img / vendor_boot.img if present

## end boot install