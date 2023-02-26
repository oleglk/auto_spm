# image_pixeldata.tcl
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

ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*
############# Done loading code ################################################


namespace eval ::img_proc:: {
    namespace export                          \
}


# Returns list of 'numSteps' relative-brightness values (0-1)
# of image 'imgPath'
# in a horizontal band of height 'bandHeight' that encloses 'bandY'
#~ proc ::img_proc::read_brightness_of_band {imgPath' bandY bandHeight numSteps}  {
  #~ set numBands [expr int($imgHeight / $bandHeight)]
#~ }


# Returns list of lists - 'numBands'*'numSteps' relative-brightness values (0-1)
# of image 'imgPath'
### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY;    img_proc::read_brightness_matrix  V24d2/DSC00589__s11d0.JPG  2 3
proc ::img_proc::read_brightness_matrix {imgPath numBands numSteps {priErr 1}}  {
  if { ![file exists $imgPath] }  {
    puts "-E- Inexistent input file '$imgPath'"
    return  0
  }
  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  set bandHeight [expr $imgHeight / $numBands]
  set wXhStr [format {%dx%d!} $numSteps $bandHeight]
  ## read data with 'convert <PATH>  -resize 3x2!  -colorspace gray  txt:-'
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set imCmd [format {|%s  %s -quiet  -resize %s  -colorspace gray  txt:-} \
                      $::IMCONVERT $imgPath $wXhStr]
  set tclExecResult [catch {
    # Open a pipe to the program
    #   set io [open "|identify -format \"%w %h\" $fullPath" r]
    set io [eval [list open $imCmd r]]
    set buf [read $io];	# Get the full reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    if { $priErr == 1 }  {
      ok_err_msg "$execResult!"
      ok_err_msg "Cannot get pixel data of '$imgPath'"
    }
    return  0
  }
  return  $buf;  # OK_TMP
}
