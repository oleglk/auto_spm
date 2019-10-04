# spm_try.tcl
# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
set ::SPM [file normalize {C:\Program Files\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

namespace eval ::spm:: {
  ### variable ORIG_PATTERN {*.tif}
  variable ORIG_PATTERN {*.jpg}
#  variable SUBDIR_INP "";  # subdirectory for to-be-aligned images - DEFAULT
  variable SUBDIR_INP "FIXED";  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE "Pre";    # subdirectory for pre-aligned images
  
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
  set wndDescr "locating main window of StereoPhotoMaker"
  if { 0 < [set HWND [twapi::find_windows -text "$SPM_TITLE" \
                              -toplevel 1 -visible 1 -single]]  }  {
    puts "-I- Success $wndDescr" } else {
    puts "-E- Failed $wndDescr";  return  0
  }

  return  $HWND
}

proc ::spm::quit_singleton {}  {
  variable PID;       # pid of the singletone instance of StereoPhotoMaker
  variable HWND;      # window handle of StereoPhotoMaker
  set descr "quitting StereoPhotoMaker instance"
  if { ![verify_singleton_running $descr] }  {
    return  1;  # OK; warning already printed
  }
  if { 1 == [focus_singleton] }  {
    twapi::send_keys {{MENU}fx};  # choose "exit" in "file" menu
    after 200; # avoid an access denied error.
    puts "-I- Success $descr"
    return  1
  }
  puts "-E- Failed $descr"
}


proc ::spm::focus_singleton {{context ""}}  {
  variable HWND;      # window handle of StereoPhotoMaker
  set descr [expr {($context != "")? $context : \
                                "giving focus to StereoPhotoMaker instance"}]
  if { ![verify_singleton_running $descr] }  {
    return  0;  # warning already printed
  }
  twapi::set_focus $HWND
  if { $HWND == [twapi::get_foreground_window] }  {
    puts "-I- Success $descr";    return  1
  } else {
    puts "-E- Failed $descr";     return  0
  }
}


proc ::spm::verify_singleton_running {contextDescr}  {
  variable HWND;      # window handle of StereoPhotoMaker
  if { $HWND == 0 }  {
    if { $contextDescr != "" }  {
      puts "-W- StereoPhotoMaker instance not running; context: $contextDescr"
    }
    return  0
  }
  return  1
}


proc ::spm::verify_current_window_by_title {title {loud 1}}  {
  set h  [twapi::get_foreground_window]
  set txt [twapi::get_window_text $h]
  if { $txt != $title } {
    if { $loud }  {
      puts "-I- Unexpected foreground window '$txt' instead of '$title'"
    }
    return  0
  }
  return  1
}


proc spm::cmd__maximize_current_window {} {
  set descr [lindex [info level 0] 0]
  _open_menu_top_level "{SPACE}" $descr
  return  [expr { [_send_cmd_keys {x} $descr] }]
}


proc spm::cmd__open_multi_conversion {} {
  set descr [lindex [info level 0] 0]
  # _send_cmd_keys {{MENU}f} $descr
  _open_menu_top_level "f" $descr
  return  [expr { [_send_cmd_keys {mm{ENTER}} $descr] && \
                  [verify_current_window_by_title "Multi Conversion"] }]
}


# Safely opens 1st level of the menu for key 'oneKey'
proc spm::_open_menu_top_level {oneKey descr} {
  set res [_send_cmd_keys [format "{MENU}%s" $oneKey] $descr]
  after 1000
  return  $res
}


proc ::spm::_send_cmd_keys {keySeqStr descr} {
  set descr "sending key-sequence {$keySeqStr} for '$descr'"
  set subSeqList [_split_key_seq_at_alt $keySeqStr]
  if { 1 == [focus_singleton "focus for $descr"] }  {
    after 1000
    if { 0 == [llength $subSeqList] }   {
      twapi::send_keys $keySeqStr
     } else {
      foreach subSeq $subSeqList  {
        twapi::send_keys {{MENU}}
        after 1000;  # wait A LOT after ALT
        twapi::send_keys $subSeq
      }
     }
    after 200; # avoid an access denied error
    puts "-I- Success $descr";      return  1
  }
  puts "-E- Cannot $descr";         return  0
}


# Returns list of subsequences that follow occurences of {MENU}/{ALT}
# In the case of no occurences of {MENU}/{ALT}, returns empty list
proc ::spm::_split_key_seq_at_alt {keySeqStr} {
  # the idea:  set list [split [string map [list $substring $splitchar] $string] $splitchar]
  set tmp [string map {\{MENU\} \uFFFF  \{ALT\} \uFFFF} $keySeqStr]
  if { [string equal $tmp $keySeqStr] }   {
    return  [list];   # no occurences of {MENU}/{ALT}
  }
  set tmpList [split $tmp \uFFFF];  # may have empty elements
  set subSeqList [list]
  foreach el $tmpList {
    if { $el != "" }  { lappend subSeqList $el }
  }
  return  $subSeqList
}


proc ::spm::align_all {}  {
  variable ORIG_PATTERN
  variable SUBDIR_INP;  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  
}