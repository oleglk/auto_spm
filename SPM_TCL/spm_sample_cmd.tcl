# spm_sample_cmd.tcl - sample command sequences

package require twapi;  #  TODO: check errors

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "disk_info.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]
source [file join $SCRIPT_DIR "spm_basics.tcl"]
source [file join $SCRIPT_DIR "spm_interlace.tcl"]


proc ::spm::ex__YOGABOOK_full_pp_dc101 {{centerBias -144}}  {
  source c:/Oleg/Work/mini3d/Mini3D_TCL/auto_postproc.tcl
  set ::IM_DIR "C:/Program Files (x86)/ImageMagick-7.0.8-20";   set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];    # YogaBook
  ::mini3d::set_scene_params  527  -10.0  208 356  1372 1908;  ::mini3d::set_border_params 10 70 300
  ::mini3d::run_full_pp_in_current_dir "*.jpg"  -144  nomask
}



proc ::spm::ex__interlace {lpi {outDir "IL"}}  {
  if { ![ok_twapi::verify_singleton_running "interlace at $lpi lpi"] }  {
    ::spm::start_spm .
  }
  ::spm::interlace_listed_stereopairs_at_integer_lpi SBS [lindex [glob -nocomplain -directory "FIXED/SBS" "*.TIF"] 0] $lpi $outDir
}


