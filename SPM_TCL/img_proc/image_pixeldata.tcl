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
#### namespace forget ::img_proc::*;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY;    set matrix [img_proc::read_brightness_matrix  V24d2/DSC00589__s11d0.JPG  2 3]
proc ::img_proc::read_brightness_matrix {imgPath numBands numSteps {priErr 1}}  {
  set matrDecr [format "%dx%d matrix" $numBands $numSteps]
  if { 0 == [set pixels [img_proc::read_pixel_values \
                          $imgPath $numBands $numSteps $priErr]] }  {
    return  0;  # error already printed
  }

  #~ # convert marked list of values into list-of-lists
  #~ if { 0 == [img_proc::_brightness_txt_to_matrix $pixels nRows nCols $priErr] }  {
    #~ ok_err_msg "Invalid pixel-data format in '$imgPath'"
    #~ return  0
  #~ }
  #~ if { ($nRows != $numBands) || ($nCols != $numSteps) } {
    #~ ok_err_msg "Invalid dimension(s) for $matrDecr out of '$imgPath': $nRows lines, $nCols columns"
    #~ return  0
  #~ }
  #~ ok_info_msg "Success parsing pixel-data of '$imgPath' into $matrDecr"
  
  return  $pixels;  # OK_TMP
}


# Returns list of formatted pixel values of image 'imgPath'
### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY;    set pixels [img_proc::read_pixel_values  V24d2/DSC00589__s11d0.JPG  2 3]
proc ::img_proc::read_pixel_values {imgPath numBands numSteps \
                                      {priErr 1}}  {
  if { ![file exists $imgPath] }  {
    ok_err_msg "-E- Inexistent input file '$imgPath'"
    return  0
  }
  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  set bandHeight [expr $imgHeight / $numBands]
  set wXhStr [format {%dx%d!} $numSteps $numBands]
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
  # split into list with element per a pixel
  set asOneLine [join $buf " "];  # data read into arbitrary chunks
  set pixels [regexp -all -inline \
        {\d+,\d+:\s+\([0-9.,]+\)\s+#[0-9A-F]+\s+gray\([0-9.]+%\)} \
        $asOneLine]

  return  $pixels
}


## Sample input data (for 2*3):
####  -I- Assume running on an unixoid - use pure tool executable names
####  # ImageMagick pixel enumeration: 3,2,255,gray
####  0,0: (133.342,133.342,133.342)  #858585  gray(52.2911%)
####  1,0: (140.304,140.304,140.304)  #8C8C8C  gray(55.021%)
####  2,0: (124.564,124.564,124.564)  #7D7D7D  gray(48.8487%)
####  0,1: (128.23,128.23,128.23)  #808080  gray(50.2861%)
####  1,1: (138.77,138.77,138.77)  #8B8B8B  gray(54.4198%)
####  2,1: (128.152,128.152,128.152)  #808080  gray(50.2556%)
# Returns dictionary {row,column :: gray-value(0.0 ... 100.0)}
proc ::img_proc::_brightness_txt_to_matrix {pixelLines nRows nCols {priErr 1}} {
  # init the resulting dict with negative values
  set resDict [dict create]
  for {set i 0}  {$i < $nRows}  {incr i 1}  {
    for {set j 0}  {$j < $nCols}  {incr j 1}  { dict set resDict  $i $j  -99 }
  }
  set errCnt 0
  set iRow 0
  set iCol 0
  foreach pixelStr $pixelLines  {
    ###puts "@@ Line '%s' simple match = []"
    if { 0 == [regexp {(\d+),(\d+):\s+.+gray\(([0-9.]+)%\)}  $pixelStr    \
                                                  all  iCol iRow  val] }  {
      if { $priErr }  { ok_err_msg "Invalid one-pixel line '$pixelStr'" }
      incr errCnt 1
      continue
    }
    dict set resDict  $iRow $iCol  $val
  }
  if { $priErr && ($errCnt > 0) }  {
    ok_err_msg "Parsing pixel values encountered $errCnt error(s)"
  }
  return  $resDict
}
