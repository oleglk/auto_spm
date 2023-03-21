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
  set hueAnglePositive [expr {($hueAngle >= 0)? $hueAngle  \
                                              : [expr 360.0 + $hueAngle]}]
  return  [expr ($hueAnglePositive * 100.0/180) + 100]
}


# Rotates image hue by 'hueAngle' and converts into red-cyan anaglyph
## Example: img_proc::hue_modulate_anaglyph  SBS/DSC03172.jpg  -18.8  ANA TMP
proc ::img_proc::hue_modulate_anaglyph {inpPath hueAngle outDir {tmpDir ""} }  {
  set hueAnglePositive [expr {($hueAngle >= 0)? $hueAngle  \
                                              : [expr 360.0 + $hueAngle]}]
  set hueStr [string map {. d} [format "%.02f" $hueAnglePositive]]
  # decide o file names
  #set outDir [file dirname [file normalize $outPath]]
  set nameNoExt [file rootname [file tail $inpPath]]
  if { $tmpDir == "" }  { set tmpDir $outDir }
  set outPathLR [file join $tmpDir "tmp_LR.JPG"]
  set outPathL  [file join $tmpDir "tmp_LR-0.JPG"];   # hardcoded rule in IM
  set outPathR  [file join $tmpDir "tmp_LR-1.JPG"];   # hardcoded rule in IM
  set outSpecLR  "-quality 95 $outPathLR"
  set outSpecANA [format "-quality 90 %s_FCA_h%s.JPG" \
                          [file join $outDir $nameNoExt] $hueStr]
  set modulateArg [img_proc::hue_angle_to_im_modulate_arg $hueAnglePositive]
  # modulate the original SBS; save into temporary separate L/R files
  set cmdM "$::IMCONVERT $inpPath  -modulate 100,100,$modulateArg  -crop 50%x100%  $outSpecLR"
  puts "(Modulation command) ==> '$cmdM'"
  exec  {*}$cmdM
  # build full-color anaglyph out of the separate L/R files
  set cmdA "$::IMCOMPOSITE -stereo 0  $outPathL $outPathR  $outSpecANA"
  puts "(Anaglyph command) ==> '$cmdA'"
  exec  {*}$cmdA
}
