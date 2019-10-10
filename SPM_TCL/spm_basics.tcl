# spm_basics.tcl  - basic procedures for automating StereoPhotoMaker

# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]

namespace eval ::spm:: {
  ### variable ORIG_PATTERN {*.tif}
  variable ORIG_PATTERN {*.jpg}
#  variable SUBDIR_INP "";  # subdirectory for to-be-aligned images - DEFAULT
  variable SUBDIR_INP "FIXED";  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE "Pre";    # subdirectory for pre-aligned images
  
  variable SPM_TITLE  "StereoPhoto Maker" ;   # title of the main SPM window
  
  variable WA_ROOT "";  # work-area root directory

  
  namespace export  \
    # (DO NOT EXPORT:)  start_singleton  \
    # (DO NOT EXPORT:)  fix_one_file
}


proc ::spm::start_spm {{workarea_rootdir ""}}  {
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
  return  [::ok_twapi::start_singleton $::SPM \
                "StereoPhotoMaker" $SPM_TITLE $workarea_rootdir]
}


proc ::spm::quit_spm {}  {
  return  [::ok_twapi::quit_singleton cmd__return_to_top]
}


# Returns 1 if the current foreground window is SPM-top or its descendant
proc ::spm::is_current_window_spm {} {
  return  [::ok_twapi::is_current_window_related]
}


proc ::spm::cmd__return_to_top {} {
  set descr "reach SPM top";  # [lindex [info level 0] 0]
  if { 0 == [::ok_twapi::focus_singleton "focus to $descr" 0] }  {
    return  0;  # warning already printed
  }
  set nAttempts 30
  for {set i 1} {$i <= $nAttempts} {incr i 1}  {
    set topWnd [ok::twapi::get_top_app_wnd]
    if { $topWnd == [set h [twapi::get_foreground_window]] }   {
      puts "-I- Success to $descr after $i hit(s) of ESCAPE"
      ::ok_twapi::set_latest_app_wnd $topWnd
      return  1
    }
    puts "-I- Pressing ESCAPE ($i of $nAttempts) to $descr"
    twapi::send_keys {{ESCAPE}}
    after 2000;  # wait A LOT after ESCAPE
  }
  puts "-E- Failed to $descr after $nAttempts hit(s) of ESCAPE"
  return  0
}


# Returns handle of resulting window or "" on error.
proc spm::cmd__open_multi_conversion {} {
  set descr [lindex [info level 0] 0]
  #twapi::block_input
  # _send_cmd_keys {{MENU}f} $descr [::ok_twapi::get_top_app_wnd]
  ::ok_twapi::open_menu_top_level "f" $descr;  # TODO: VERIFY SUCCESS"
  if { 0 == [::ok_twapi::travel_meny_hierarchy {{m 2}{ENTER}} \
                                      $descr "Multi Conversion"] }  {
    #twapi::unblock_input
    return  "";  # error already printed
  }
  if { 0 == [cmd__maximize_current_window] }  {
    #twapi::unblock_input
    return  "";  # error already printed
  }
  #twapi::unblock_input
  return  [::ok_twapi::set_latest_app_wnd_to_current]
}



proc ::spm::align_all {}  {
  variable ORIG_PATTERN
  variable SUBDIR_INP;  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  
}