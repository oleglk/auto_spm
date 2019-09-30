# spm_try.tcl
# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'
# set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}]

package require twapi;  #  TODO: check errors

namespace eval ::spm:: {
  ### variable ORIG_PATTERN {*.tif}
  variable ORIG_PATTERN {*.jpg}
  
  variable SPM_TITLE  "StereoPhoto Maker"
  
  variable PID 0;       # pid of the singletone instance of StereoPhotoMaker
  variable HWND 0;      # window handle of StereoPhotoMaker
  variable WA_ROOT "";  # work-area root directory

  
  namespace export  \
    # (DO NOT EXPORT:)  start_singleton  \
    # (DO NOT EXPORT:)  fix_one_file
}


proc ::spm::start_singleton {{workarea_rootdir ""}}  {
  variable PID
  variable HWND
  variable WA_ROOT
  variable SPM_TITLE
  if { $workarea_rootdir != "" }  {
    if { ![file isdirectory $workarea_rootdir] }  {
      puts "-E- Invalid or inexistent directory '$workarea_rootdir'"
      return  0
    }
    set WA_ROOT [file normalize $workarea_rootdir]
    puts "-I- Workarea root directory set to '$WA_ROOT'"
  }
  set execDescr "invoking StereophotoMaker"
  if { 0 < [set PID [exec $::SPM &]] }  {
    puts "-I- Success $execDescr" } else {
    puts "-E- Failed $execDescr";  return  0
  }
  set execDescr "locating main window of StereophotoMaker"
  if { 0 < [set HWND [twapi::find_windows -text "$SPM_TITLE" \
                              -toplevel 1 -visible 1 -single]]  }  {
    puts "-I- Success $execDescr" } else {
    puts "-E- Failed $execDescr";  return  0
  }

  return  $HWND
}
