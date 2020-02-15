# ext_tools.tcl

set SCRIPT_DIR [file dirname [info script]]
set UTIL_DIR    [file join $SCRIPT_DIR "ok_utils"]
source [file join $UTIL_DIR "debug_utils.tcl"]
source [file join $UTIL_DIR "csv_utils.tcl"]

# DO NOT in 'auto_spm': package require ok_utils
namespace import -force ::ok_utils::*

ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"

## Better call path-reading function explicitly from another function
## read_ext_tool_paths_from_csv [file join $SCRIPT_DIR "ext_tool_dirs.csv"]

# - external program executable paths;
# - don't forget to add if using more;
# - COULDN'T PROCESS SPACES (as in "Program Files");

#~ # - ImageMagick:
#~ set _IM_DIR [file join {C:/} {Program Files (x86)} {ImageMagick-6.8.7-3}] ; # DT
#~ #set _IM_DIR [file join {C:/} {Program Files} {ImageMagick-6.8.6-8}]  ; # Asus
#~ #set _IM_DIR [file join {C:/} {Program Files (x86)} {ImageMagick-6.8.6-8}]; # Yoga

#~ set _IMCONVERT [format "{%s}" [file join $_IM_DIR "convert.exe"]]
#~ set _IMIDENTIFY [format "{%s}" [file join $_IM_DIR "identify.exe"]]
#~ set _IMMONTAGE [format "{%s}" [file join $_IM_DIR "montage.exe"]]
#~ # - DCRAW:
#~ #set _DCRAW "dcraw.exe"
#~ set _DCRAW [format "{%s}" [file join $_IM_DIR "dcraw.exe"]]
#~ # - ExifTool:
#~ set _EXIFTOOL "exiftool.exe" ; #TODO: path


####### Do not change after this line ######

# Reads the system-dependent paths from 'csvPath',
# then assigns ultimate tool paths
proc set_ext_tool_paths_from_csv {csvPath}  {
  unset -nocomplain ::_IMCONVERT ::_IMIDENTIFY ::_IMMONTAGE ::_DCRAW ::_EXIFTOOL
  if { 0 == [ok_read_variable_values_from_csv \
                                      $csvPath "external tool path(s)"]} {
    return  0;  # error already printed
  }
  return  [_set_ext_tool_paths_from_variables "source: '$csvPath'"]
}


# Reads the system-dependent paths from their global variables,
# then assigns ultimate tool paths
proc _set_ext_tool_paths_from_variables {srcDescr}  {
  unset -nocomplain ::_IMCONVERT ::_IMIDENTIFY ::_IMMONTAGE ::_DCRAW ::_EXIFTOOL
  if { 0 == [info exists ::IM_DIR] }  {
    ok_err_msg "Imagemagick directory path not assigned to variable _IM_DIR; $srcDescr"
    return  0
  }
  set ::_IMCONVERT  [format "{%s}"  [file join $::IM_DIR "convert.exe"]]
  set ::_IMIDENTIFY [format "{%s}"  [file join $::IM_DIR "identify.exe"]]
  set ::_IMMONTAGE  [format "{%s}"  [file join $::IM_DIR "montage.exe"]]
  # - DCRAW:
  # unless ::_DCRAW_PATH points to some custom executable, point at the default
  if { (![info exists ::_DCRAW_PATH]) || (""== [string trim $::_DCRAW_PATH]) } {
    set ::_DCRAW      [format "{%s}"  [file join $::IM_DIR "dcraw.exe"]]
  } else {
    ok_info_msg "Custom dcraw path specified; $srcDescr"
    set ::_DCRAW      [format "{%s}"  $::_DCRAW_PATH]
  }
  # - ExifTool:
  ## set ::_EXIFTOOL "exiftool.exe" ; #TODO: path
  return  1
}


# Copy-pasted from Lazyconv "::dcraw::is_dcraw_result_ok"
# Verifies whether dcraw command line ended OK through the test it printed.
# Returns 1 if it was good, 0 otherwise.
proc is_dcraw_result_ok {execResultText} {
    # 'execResultText' tells how dcraw-based command ended
    # - OK if noone of 'errKeys' appears
    set result 1;    # as if it ended OK
    set errKeys [list {Improper} {No such file} {missing} {unable} {unrecognized} {Non-numeric}]
#     puts ">>> Check for error keys '$errKeys' the following string:"
#     puts "--------------------------------------------"
#     puts "'$execResultText'"
#     puts "--------------------------------------------"
    foreach key $errKeys {
	if { [string first "$key" $execResultText] >= 0 } {    set result 0  }
    }
    return  $result
}


proc verify_external_tools {} {
  set errCnt 0
  if { 0 == [file isdirectory $::IM_DIR] }  {
    ok_err_msg "Inexistent or invalid Imagemagick directory '$::IM_DIR'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMCONVERT " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'convert' tool '$::_IMCONVERT'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMIDENTIFY " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'identify' tool '$::_IMIDENTIFY'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMMONTAGE " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'montage' tool '$::_IMMONTAGE'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_DCRAW " {}"]] }  {
    ok_err_msg "Inexistent 'dcraw' tool '$::_DCRAW'"
    incr errCnt 1
  }
  if { ([info exists ::_ENFUSE_DIR]) &&               \
       ("" != [string trim $::_ENFUSE_DIR " {}"]) &&  \
       (![ok_filepath_is_existent_dir [string trim $::_ENFUSE_DIR " {}"]]) }  {
    ok_err_msg "Inexistent or invalid 'enfuse' directory '$::_ENFUSE_DIR'"
    incr errCnt 1
  }
  if { $errCnt == 0 }  {
    ok_info_msg "All external tools are present"
    return  1
  } else {
    ok_err_msg "Some or all external tools are missing"
    return  0
  }
}


# Retrieves external tools' paths from their variables.
# Returns list of {key val} pair lists
proc ext_tools_collect_and_verify {srcDescr}  {
  global _IM_DIR _DCRAW_PATH _ENFUSE_DIR
  set listOfPairs [list]
  if { ([info exists _IM_DIR]) && ("" != [string trim $_IM_DIR]) } {
    lappend listOfPairs [list "_IM_DIR"     $_IM_DIR] }
  if { ([info exists _DCRAW_PATH]) && ("" != [string trim $_DCRAW_PATH]) } {
    lappend listOfPairs [list "_DCRAW_PATH" $_DCRAW_PATH] }
  if { ([info exists _ENFUSE_DIR]) && ("" != [string trim $_ENFUSE_DIR]) } {
    lappend listOfPairs [list "_ENFUSE_DIR" $_ENFUSE_DIR] }
  if { 0 == [_set_ext_tool_paths_from_variables $srcDescr] }  {
    return  0;  # error already printed
  }
  if { 0 == [verify_external_tools] }  {
    return  0;  # error already printed
  }
  #puts "@@@ {$listOfPairs}";  set ::_TMP_PATHS $listOfPairs
  return  $listOfPairs
}


proc ext_tools_collect_and_write {srcDescr}  {
  set extToolsAsListOfPairs [ext_tools_collect_and_verify $srcDescr]
  if { $extToolsAsListOfPairs == 0 }  {
    return  0;  # error already printed
   }
  return  [ext_tools_write_into_file $extToolsAsListOfPairs]
}


# Saves the obtained list of pairs (no header) in the predefined path.
# Returns 1 on success, 0 on error.
proc ext_tools_write_into_file {extToolsAsListOfPairs}  {
  set pPath [dualcam_find_toolpaths_file 0]
  if { 0 == [CanWriteFile $pPath] }  {
    ok_err_msg "Cannot write into external tool paths file <$pPath>"
    return  0
  }
  # prepare wrapped header; "concat" data-list to it 
  set header [list [list "Environment-variable-name" "Path"]]
  set extToolsListWithHeader [concat $header $extToolsAsListOfPairs]
  return  [ok_write_list_of_lists_into_csv_file $extToolsListWithHeader \
                                                $pPath ","]
}
