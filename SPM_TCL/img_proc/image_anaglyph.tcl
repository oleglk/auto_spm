# image_anaglyph.tcl
# Copyright (C) 2023 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


# DO NOT for utils:  set SCRIPT_DIR [file dirname [info script]]
set IMGPROC_DIR [file dirname [info script]]
set UTIL_DIR    [file join $IMGPROC_DIR ".." "ok_utils"]
source [file join $UTIL_DIR     "debug_utils.tcl"]
source [file join $UTIL_DIR     "common.tcl"]
source [file join $IMGPROC_DIR  "image_metadata.tcl"]
source [file join $IMGPROC_DIR  "image_pixeldata.tcl"]

ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*
############# Done loading code ################################################


namespace eval ::img_proc:: {
    namespace export                          \
}

################################################################################
## How to split an SBS and combine into red-cyan anaglyph:
#### convert -crop 50%x100%  -quality 90 SBS/DSC03172.jpg LR/DSC03172.jpg
#### composite -stereo 0  LR/DSC03172-0.jpg LR/DSC03172-1.jpg  -quality 90  ANA/DSC03172_FCA.jpg
################################################################################

## How to rotate hue in an image:
######### TODO: the results aren't as expected !!!!!
### Conversion formulas between angle and the modulate argument is...
###    hue_angle = ( modulate_arg - 100 ) * 180/100
###    modulate_arg = ( hue_angle * 100/180 ) + 100
#### convert SBS/DSC03172.jpg  -modulate 100,100,199.94  -quality 90  TMP/DSC03172_359d9.jpg
################################################################################


proc ::img_proc::hue_angle_to_im_modulate_arg {hueAngle}  {
  return  [expr ($hueAngle * 100.0/180) + 100]
}


proc ::img_proc::_modulate_hue_TODO {inpName hueAngle}  {
#~ img_proc::hue_angle_to_im_modulate_arg [expr 360.0 - 18.8]
#~ convert SBS/DSC03172.jpg  -modulate 100,100,289.6  -quality 90  TMP/DSC03172_289d6.jpg
#~ convert -crop 50%x100%  -quality 90  TMP/DSC03172_289d6.jpg  LR/DSC03172_289d6.jpg
#~ composite -stereo 0  LR/DSC03172_289d6-0.jpg LR/DSC03172_289d6-1.jpg   -quality 90  ANA/DSC03172_289d6_FCA.jpg
}
