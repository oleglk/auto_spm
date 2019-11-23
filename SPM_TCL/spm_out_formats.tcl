# spm_out_formats.tcl - formats ready SBS stereopairs for various output devices

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "disk_info.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]
source [file join $SCRIPT_DIR "spm_basics.tcl"]


## Example:
##  set formatProcList  [list \
##                ::spm::cmd__format_all__SBS_3840x2160     \
##                ::spm::cmd__format_all__HAB_1920x1080     \
##                ::spm::cmd__format_all__HSBS_1920x1080    ]
##  spm::make_output_formats_in_current_dir $formatProcList phasesToBadImgs
##  # Now 'phaseNameToBadImgList' is a dict of phase-id :: list-of-failed-images
proc ::spm::make_output_formats_in_current_dir {formatProcList \
                                      phaseNameToBadImgList {reportErrors 1}}  {
  upvar $phaseNameToBadImgList phasesToBadImgs;  # dict of phase-id :: list-of-failed-images
  set descr "convert to output formats"
  
  set spmWaRoot [file normalize "."]
  if { ![set spmWasRunning [::ok_twapi::verify_singleton_running $descr]] }  {
    if { 0 == [::spm::start_spm $spmWaRoot] }   {
      return  0;   # error already printed
    }
  }
  if { ![info exists phasesToBadImgs] ||   \
        ($phasesToBadImgs == 0) } {
    set phasesToBadImgs [dict create] ;               # for the caller
    if { ![spm::are_phase_results_initialized] }  {
      spm::init_phase_results ;                       # in ::spm:: namespace
    }                                                                         
  }                                                                                             
  
  set nPhases_before [dict size $phasesToBadImgs]
  
  foreach procName $formatProcList {
    puts "\n\n          ----------------------\n\n"
    puts "------- Formatting output with $procName --------------------"
    if { 0 == [$procName  SBS] }   {
      continue;   # error already printed
    }
    dict set phasesToBadImgs   $procName                       \
                                              [spm::get_phase_errors $procName]
  }
  puts "\n\n          ----------------------\n\n"
  if { ! $spmWasRunning }   { ::spm::quit_spm };  # no reason to check errors
  
  set nPhases_after [dict size $phasesToBadImgs]
  set nPhases [expr {$nPhases_after - $nPhases_before}]
  puts "\n\n          ----------------------\n\n"
  if { $reportErrors }  {
    set nPhasesWithErrors [count_and_report_flow_phases_with_errors $phasesToBadImgs]
    set errReportStr "  Errors occured in $nPhasesWithErrors phase(s)"
  } else {
    set errReportStr ""
  }
  puts "-I- End   stereopair output format conversions; performed $nPhases phases(s) out of [llength $formatProcList].$errReportStr"
  puts "\n\n          ----------------------\n\n"
  return  1
}


# Deletes from all output directories images absent from 'subdirToFollow'.
# Image filenames matched from beginning till 'nameSuffixStartRegexp'.
proc ::spm::clean_stereopairs_and_outputs_in_current_dir {rootSubdirOrEmpty  \
              subdirToFollowRelPath nameSuffixStartRegexp {simulateOnly 0}}   {
  variable SUBDIR_SBS;    # subdirectory for final images
  variable SUBDIR_OUTFORMAT_ROOT; # subdirectory for formated-for-outputs images
  set descr "clean output images not in '$subdirToFollowRelPath'"
  
  set waRoot [file normalize "."]
  set spmWaRoot [file join $waRoot $rootSubdirOrEmpty]
  set formatsRoot [file join $rootSubdirOrEmpty $SUBDIR_OUTFORMAT_ROOT]; # relative
  set subDirRelPaths [list "SBS"];  # TODO: SBS/, all FORMATTED/*
  set dirRelPaths [glob -nocomplain -directory $formatsRoot -types d -- {*}]
  set subDirRelPaths [concat $subDirRelPaths $dirRelPaths]
  set actDescr "$descr from directories {$subDirRelPaths}"
  # TODO?: verify 'subdirToFollowRelPath' appears in 'subDirRelPaths'
  puts "Going to $actDescr"
  set subdirToFollowUnderRoot [expr {($subdirToFollowRelPath == $SUBDIR_SBS)?  \
    [file join $rootSubdirOrEmpty $subdirToFollowRelPath] : \
    [file join $rootSubdirOrEmpty $SUBDIR_OUTFORMAT_ROOT $subdirToFollowRelPath]}]
  if { ![file exists $subdirToFollowUnderRoot] || \
       ![file isdirectory $subdirToFollowUnderRoot] }  {
    puts "-E- Invalid or inexistent directory with desired images '$subdirToFollowUnderRoot' under '$spmWaRoot'"
    return  0
  }
  # TODO: build list of basenames being present
  set namesToKeep [list]
  foreach typePattern {"*.JPG" "*.TIF"}   {
    set namesToKeep [concat $namesToKeep [glob -nocomplain -tails \
                              -directory $subdirToFollowUnderRoot $typePattern]]
  }
  set baseNamesToKeep [list]
  foreach fName $namesToKeep  {
    set baseName [file rootname $fName]
    if { ($nameSuffixStartRegexp != "") &&  \
         [regexp "(.*)$nameSuffixStartRegexp" $baseName all nameNoSuffix] }  {
      set baseName $nameNoSuffix
    }
    lappend baseNamesToKeep $baseName
  }
  set baseNamesToKeep [lsort -unique $baseNamesToKeep]
  puts "-I- Image names to be preserved - taken in '$subdirToFollowUnderRoot': {$baseNamesToKeep}"
  # TODO: browse all subdirs and detect unneeded images
  return  1
}


# TODO: move intp spm_basics.tcl
proc ::spm::count_and_report_flow_phases_with_errors {phaseNameToBadImgList}  {
  set nPhasesWithErrors 0
  dict for {phase badList} $phaseNameToBadImgList {
    incr nErrors [llength $badList]
    set msg "Phase '$phase' encountered [llength $badList] error(s)"
    if { 0 == [llength $badList] }  { puts "-I- $msg"}  else  { puts "-E- $msg"}
    if { 0 != [llength $badList] }  { incr nPhasesWithErrors 1 }
  }
  return  $nPhasesWithErrors
}
