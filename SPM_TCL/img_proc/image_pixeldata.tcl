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


# regular expression to parse one pixel grayscale value
set ::_ONE_PIXEL_CHANNEL_DATA_REGEXP  {(\d+),(\d+):\s+.+gray\(([0-9.]+)%?\)}


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


############# BEGIN: pixel-data READING stuff ##################################
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
        {\d+,\d+:\s+\([0-9.,]+\)\s+#[0-9A-F]+\s+gray\([0-9.]+%?\)} \
        $asOneLine]

  return  $pixels
}


# Returns list of formatted pixel Hue values of image 'imgPath'
### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY;    set pixels [img_proc::read_pixel_hues  rose.tif  1]
proc ::img_proc::read_pixel_hues {imgPath scale {priErr 1}}  {
  if { ![file exists $imgPath] }  {
    ok_err_msg "-E- Inexistent input file '$imgPath'"
    return  0
  }
  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  set newWidth  [expr $imgWidth  / $scale]
  set newHeight [expr $imgHeight / $scale]
  set wXhStr [format {%dx%d!} $newWidth $newHeight]
  ## read data with 'convert <PATH>  -resize 3x2!  -colorspace HSB -channel Hue -separate  txt:-'
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set imCmd [format {|%s  %s -quiet  -resize %s  -colorspace HSB -channel Hue -separate  txt:-} \
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
        {\d+,\d+:\s+\([0-9.,]+\)\s+#[0-9A-F]+\s+gray\([0-9.]+%?\)} \
        $asOneLine]

  return  $pixels
}
############# END:   pixel-data READING stuff ##################################



############# BEGIN: pixel-data annotation stuff ###############################
proc ::img_proc::_plain_string_CB {v} { return [format "%s" $v] }
proc ::img_proc::_float_to_string_CB {v} { return [format "%.2f" $v] }


### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;    source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY
#### img_proc::annotate_pixel_values  V24d2/DSC00589__s11d0.JPG  6 9    "__br6x9"  "OUT"  _float_to_string_CB
proc ::img_proc::annotate_pixel_values {imgPath numBands numSteps \
                  outNameSuffix outDir {formatCB img_proc::_plain_string_CB}}  {
  if { 0 == [set pixels [img_proc::read_pixel_values  \
                                          $imgPath $numBands $numSteps 1]] }  {
    return  0;  # error already printed
  }
  if { 0 == [set brMatrix [img_proc::_brightness_txt_to_matrix \
                            $pixels  $numBands $numSteps  1  1]] }  {
    return  0;  # error already printed
  }

  #set outNameSuffix [format {__br%dx%d} $numBands $numSteps]
  return  [img_proc::annotate_image_zone_values $imgPath $brMatrix    \
                                              $outNameSuffix $outDir $formatCB]
}


# 'valDict' = dictionary {row,column :: numeric-value
# Output file created in 'outDir' or the current directory.
## Example1:  img_proc::annotate_image_zone_values  V24d2/DSC00589__s11d0.JPG  {0 {0 11 1 12 2 13}  1 {0 21 1 22 2 23}}  "_a2x3"  "OUT"  img_proc::_float_to_string_CB
## Example2:  img_proc::annotate_image_zone_values  V24d2/DSC00589__s11d0.JPG  {0 {0 11 1 12 2 13 3 14 4 15}  1 {0 21 1 22 2 23 3 24 4 25}}  "_a2x5"  "OUT"  img_proc::_float_to_string_CB
proc ::img_proc::annotate_image_zone_values {imgPath valDict outNameSuffix  \
                  outDir {formatCB img_proc::_plain_string_CB}}  {
  # detect annotation-grid dimensions
  set maxBandIdx -1;  set maxStepIdx  -1
  dict for {y x_v} $valDict  {
    dict for {x v} $x_v {
      if { $y > $maxBandIdx }   { set maxBandIdx $y }
      if { $x > $maxStepIdx }   { set maxStepIdx $x }
    }
  }
  set numBands [expr $maxBandIdx + 1];  set numSteps [expr $maxStepIdx + 1]
  ## do not read pixel-data here
  #~ if { 0 == [set pixels [img_proc::read_pixel_values  \
                                    #~ $imgPath $numBands $numSteps 1]] }  {
    #~ return  0
  #~ }
  set outName [format "%s%s.jpg" \
                          [file rootname [file tail $imgPath]]  $outNameSuffix]
  if { $outDir == "" }  { set outDir [pwd] }
  if { !([file exists $outDir] && [file isdirectory $outDir]) }   {
    ok_err_msg "-E- Inexistent or invalid output directory '$outDir'; aborting"
    return  0
 }
  set outPath [file join $outDir $outName]
  set bXs [format {%dx%d} $numBands $numSteps]
  
  # compute text size and cell locations
  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  set textLength [string length [eval $formatCB 0.123456789]]
  set bandHeight  [expr int(      $imgHeight / $numBands)]
  set cellWidth   [expr int(      $imgWidth  / $numSteps)]
  set pointSize   [expr int( min(0.3*$imgHeight/$numBands, \
                                 0.9*$imgWidth/$numSteps/$textLength) )]

  ok_info_msg "Going to annotate image '$imgPath' with $bXs value grid; output into '$outPath'"
  
  set imAnnotateParam  " \
        -gravity northwest -stroke \"#000C\" -strokewidth 2 -pointsize $pointSize"
  for {set b 0}  {$b < $numBands}  {incr b 1}  {
    set y [expr {int( $b * $bandHeight  +  0.5*($bandHeight - $pointSize) )}]
    for {set s 0}  {$s < $numSteps}  {incr s 1}  {
      set x [expr {int( ($s * $cellWidth)  +  $pointSize)}]
      set txt [expr {[dict exists $valDict $b $s]?  \
                          [eval $formatCB [dict get $valDict $b $s]] : "---"}]
      append imAnnotateParam [format "  -annotate +%d+%d \"$txt\"" $x $y]
    }
  }
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set cmd "$::IMCONVERT  $imgPath  $imAnnotateParam  -depth 8 -quality 90 $outPath"
  puts "(Annotation command) ==> '$cmd'"
  exec  {*}$cmd

  puts "Created image '$outPath' annotated with $bXs value grid"
  return  1
}
############# END:   pixel-data annotation stuff ###############################



## Sample input data (for 2*3):
####  -I- Assume running on an unixoid - use pure tool executable names
####  # ImageMagick pixel enumeration: 3,2,255,gray
####  0,0: (133.342,133.342,133.342)  #858585  gray(52.2911%)
####  1,0: (140.304,140.304,140.304)  #8C8C8C  gray(55.021%)
####  2,0: (124.564,124.564,124.564)  #7D7D7D  gray(48.8487%)
####  0,1: (128.23,128.23,128.23)  #808080  gray(50.2861%)
####  1,1: (138.77,138.77,138.77)  #8B8B8B  gray(54.4198%)
####  2,1: (128.152,128.152,128.152)  #808080  gray(50.2556%)
# If 'normalize'=0, returns dictionary {row,column :: gray-value(0.0 ... 100.0)}
# If 'normalize'=1, returns dictionary {row,column :: fract_of_max(0.0 ... 1.0)}
# On error returns 0.
proc ::img_proc::_brightness_txt_to_matrix {pixelLines nRows nCols normalize \
                                            {priErr 1}} {
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
    if { 0 == [regexp {(\d+),(\d+):\s+.+gray\(([0-9.]+)%?\)}  $pixelStr    \
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
  if { $normalize == 0 }  {
    return  $resDict;   # scaling values to 0..1 isn't requested
  }
  
  # scale values to 0...1
  set maxBright -1;  set maxPlace {-1 -1}
  dict for {x y_b} $resDict  {
    dict for {y b} $y_b {
      if { $b > $maxBright }  { set maxBright $b;  set maxPlace [list $x $y] }
    }
  }
  if { $maxBright == 0.0 }  {
    ok_err_msg "-E- Zero maximal brightness (at $maxPlace) - cannot normalize"
    return  0
  }
  set scaledDict [dict create]
  for {set i 0}  {$i < $nRows}  {incr i 1}  {
    for {set j 0}  {$j < $nCols}  {incr j 1}  {
      dict set scaledDict  $i $j  \
              [expr {1.0 * [dict get $resDict $i $j] / $maxBright}] }
  }
  return  $scaledDict
}


# TODO: threshold (units - prc or fraction depend on 'normalize') !!!
## Example:  set hist [img_proc::_channel_txt_to_histogram  $pixels  1  1];  llength $hist
## Nice-print the histogram:  dict for {k v} $hist  {puts "$k :: $v"}
## Verify normalized:  proc ladd L {expr [join $L +]+0};  ladd [dict values $hist]
## Make sample input 1: exec convert -size 10x10 xc:rgb(0,11,255)  near_blue.tif
## Make sample input 2: exec convert rose: rose.tif
## Read pixels from file: set pixels [img_proc::read_pixel_hues  rose.tif  1 1] 
proc ::img_proc::_channel_txt_to_histogram {pixelLines precision normalize \
                                              {priErr 1}} {
  set threshold -1; # OK_TMP
  set precSpec [format {%%.%df} $precision]
  set allValDict [dict create];  # will contain counts for all appearing values
  set errCnt 0
  set iRow 0
  set iCol 0
  foreach pixelStr $pixelLines  {
    ###puts "@@ Line '%s' simple match = []"
    if { 0 == [regexp $::_ONE_PIXEL_CHANNEL_DATA_REGEXP  $pixelStr    \
                                                  all  iCol iRow  val] }  {
      if { $priErr }  { ok_err_msg "Invalid one-pixel line '$pixelStr'" }
      incr errCnt 1
      continue
    }
    set key [format $precSpec $val]
    dict incr allValDict  $key 1
  }
  if { $priErr && ($errCnt > 0) }  {
    ok_err_msg "Parsing pixel values encountered $errCnt error(s)"
  }
  if { ($normalize == 0) && ($threshold < 0) }  {
    return  $allValDict;   # scaling values to 0..1 isn't requested
  }
  
  # scale values to 0...1
  set numPixels [expr [llength $pixelLines] - $errCnt]
  set normDict [dict create]
  dict for {val count} $allValDict  {
    dict set normDict  $val  [expr 1.0 * $count / $numPixels]
  }
  return  $normDict
}


## Example:  img_proc::_channel_histogram_to_ordered_fragments $hist {{0 2.0}}
proc ::img_proc::_channel_histogram_to_ordered_fragments {histogramDict \
                                                          fragmentBounds}   {
  set keys [lsort -real [dict keys $histogramDict]]
  set fragmentsDict [dict create]
  foreach fragmentMinMax $fragmentBounds  {
    if { 2 != [llength $fragmentMinMax] } {
      error "-E- Invalid structure of fragment bounds '$fragmentMinMax'; should be {min max}"
    }
    lassign $fragmentMinMax lo hi;  # min/max channel values in the fragment
    dict set fragmentsDict $fragmentMinMax 0;  # init to no-values-in-fragment
    if { -1 == [set iLast [lsearch -bisect $keys $hi]] }  {
      # no valuies in this histogram fragment 
      continue
    }
    puts "-D- Last key for $hi is at #$iLast"
    set cntInFragm 0
    for {set i $iLast} {$i >= 0} {incr i -1}   {
      set key [lindex $keys $i];  # key has semantics of channel value
      if { $key >= $lo }  {
        set cntForVal [dict get $histogramDict $key];  # known to exist
        puts "-D- Contribute $cntForVal into {$fragmentMinMax} at $key"
        set cntInFragm [expr $cntInFragm + $cntForVal]
      } else {
        break;  # done with the current fragmemt
      }
    }
    dict set fragmentsDict $fragmentMinMax $cntInFragm
  }
  return  $fragmentsDict
}


## Example:  set gaps [img_proc::_find_gaps_in_channel_histogram $hist 0.001 {0 2.0}]
proc ::img_proc::_find_gaps_in_channel_histogram {histogramDict thresholdNorm \
                                                      {searchBounds "NONE"}}  {
  set keys [lsort -real [dict keys $histogramDict]];  # keys are channel values
  set numKeys [llength $keys]
  if { $searchBounds == "NONE" }  {
    set minV [lindex $keys 0];  set maxV [lindex $keys end]
  } else {
    if { 2 != [llength $searchBounds] } {
      error "-E- Invalid structure of search bounds '$searchBounds'; should be {min max}"
    }
    lassign $searchBounds argMinV argMaxV
    set minV [expr max($argMinV, [lindex $keys 0])]
    set maxV [expr min($argMaxV, [lindex $keys end])]
  }
  set gapsDict [dict create];   # will map gapFirstValue :: gapLastValue
  # find the search-start index (-bisect gives last idx with element <= pattern)
  if { -1 == [set iPrev [ \
                  lsearch -real -bisect $keys [expr $minV - 0.0001]]] }  {
    set iPrev 0; # start from the beginning
  }
  if { -1 == [set iLast [ \
                  lsearch -real -bisect $keys [expr $maxV + 0.0001]]] }  {
    # no valuies in requested histogram range
    return  $gapsDict
  }
  if { $iPrev == [expr $numKeys - 1] }  {
    # no valuies in requested histogram range
    return  $gapsDict
  }
  set keysSubList [lrange $keys  $iPrev  [expr $iLast - 1]]
  for {set i 0} {$i < [expr [llength $keysSubList] - 1]} {incr i} {
    # check for a gap started from #i
    for {set j $i} {$j < [llength $keysSubList]} {incr j}   {
      set isLastSubrange [expr {$j == [llength $keysSubList] - 1}]
      set subrangeVal [lindex $keysSubList $j]
      set subrangeCount [dict get $histogramDict $subrangeVal]
      puts "-D- \[$i\] val=$subrangeVal cnt=$subrangeCount"
      if { ($subrangeCount > $thresholdNorm) && ($j == $i) }   {
        # gap not started (j==i)
        break;   # no gap - the subrange has pixels;  goto incrementing i
      }
      if { ($subrangeCount > $thresholdNorm)  && ($j > $i) }   {
        # gap ended (j>i) - started at #i and ended at #j-1
        dict set gapsDict \
                  [lindex $keysSubList $i]  [lindex $keysSubList [expr $j-1]]
        set i $j
        break;   # gap ended - the subrange has pixels;  goto incrementing i
      }      
      if { ($subrangeCount <= $thresholdNorm) && $isLastSubrange }   {
        # gap ended (j==i) - started at #i and ended at #i
        dict set gapsDict  [lindex $keysSubList $i]  [lindex $keysSubList $i]
        break;   # gap at the last subrange;  goto incrementing i; loop will end
      }
      # gap continues
    }; #__loop_over_subranges_in_one_gap
  }; #__loop_over_all_subranges
  puts "Found [dict size $gapsDict] gap(s) in value range $minV...$maxV (== [lindex $keysSubList 0]...[lindex $keysSubList end])"
  return  $gapsDict
}
