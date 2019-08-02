### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
### AnyKernel setup
# begin properties
properties() { '
kernel.string=Spacewar by @Biased69-KittenLover
kernel.revision=5.4
kernel.made=Biased69-Kitty
anykernel3.made=osm0sis @ xda-developers
kernel.compiler=Neutron clang 24.0.0
do.devicecheck=0
do.cleanup=1
supported.versions=11.0-17.0
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

# shell variables
block=boot;
is_slot_device=auto;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel boot install
dump_boot;
vbmeta_disable_verification;

write_boot;
## end boot install

# boot install
#if [ -L "/dev/block/bootdevice/by-name/init_boot_a" -o -L "/dev/block/by-name/init_boot_a" ]; then
#    split_boot # for devices with init_boot ramdisk
#    flash_boot # for devices with init_boot ramdisk
#else
#    dump_boot # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk
#    write_boot # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
#fi
## end boot install

