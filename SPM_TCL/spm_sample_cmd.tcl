# spm_sample_cmd.tcl - sample command sequences

package require twapi;  #  TODO: check errors

set SCRIPT_DIR [file dirname [info script]]

# first, provide tool paths
source [file join $SCRIPT_DIR "ext_tools.tcl"]
if { 0 == [set_ext_tool_paths_from_csv \
                      [file join $env(HOME) "dualcam_ext_tool_dirs.csv"]] }   {
  return;  # error already printed
}

source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "disk_info.tcl"]
source [file join $SCRIPT_DIR "img_proc" "image_manip.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]
source [file join $SCRIPT_DIR "spm_basics.tcl"]
source [file join $SCRIPT_DIR "spm_interlace.tcl"]

namespace eval ::spm:: {
  variable EX_LENS_LPI    60
  variable EX_PRINT_DPI   300
  variable EX_PRINT_WD    400
}


proc ::spm::ex__YOGABOOK_full_pp_dc101 {{centerBias -144}}  {
  source c:/Oleg/Work/mini3d/Mini3D_TCL/auto_postproc.tcl
  #set ::_IM_DIR "C:/Program Files (x86)/ImageMagick-7.0.8-20";   set ::_SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];    # YogaBook
  ::mini3d::set_scene_params  527  -10.0  208 356  1372 1908;  ::mini3d::set_border_params 10 70 300
  ::mini3d::run_full_pp_in_current_dir "*.jpg"  -144  nomask
}

# cd e:/TMP/SPM/290919__Glen_Mini3D
proc ::spm::ex__WIN7DT_full_pp_dc101 {{centerBias -144}}  {
  source d:/Work/DualCam/mini3d/Mini3D_TCL/auto_postproc.tcl
  #set ::_IM_DIR "C:/program Files/ImageMagick-6.7.1-Q16";  set ::_SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}]
  ::mini3d::set_scene_params  527  -10.0  208 356  1372 1908;  ::mini3d::set_border_params 10 70 300
  ::mini3d::run_full_pp_in_current_dir "*.jpg"  -144  nomask
}

# cd e:/TMP_DC/TRY_AUTO/DC101/290919__Glen_Mini3D/
proc ::spm::ex__MIIX320_full_pp_dc101 {{centerBias -144}}  {
  source c:/Work/Code/Mini3D/Mini3D_TCL/auto_postproc.tcl
  #set ::_IM_DIR "c:/program files/ImageMagick-7.0.8-10";    set ::_SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
  ::mini3d::set_scene_params  527  -10.0  208 356  1372 1908;  ::mini3d::set_border_params 10 70 300
  ::mini3d::run_full_pp_in_current_dir "*.jpg"  -144  nomask
}

########### Begin: Interlacing #################################################

proc ::spm::ex__YOGABOOK_interlace {{outDir "IL"}}  {
  source c:/Oleg/Work/mini3d/Mini3D_TCL/auto_postproc.tcl
  set ::IM_DIR "C:/Program Files (x86)/ImageMagick-7.0.8-20";   set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];    # YogaBook
  if { ![ok_twapi::verify_singleton_running "interlace at $spm::EX_LENS_LPI lpi"] }  {
    ::spm::start_spm .
  }
  set listAll [glob -nocomplain -directory "FIXED/SBS" "*.TIF"]
  set listOne [lindex $listAll 0]
  ::spm::interlace_listed_stereopairs_at_integer_lpi SBS $listAll $outDir \
            $spm::EX_LENS_LPI $spm::EX_PRINT_DPI $spm::EX_PRINT_WD
}


proc ::spm::ex__WIN7DT_interlace {{outDir "IL"}}  {
  source d:/Work/DualCam/mini3d/Mini3D_TCL/auto_postproc.tcl
  #set ::_IM_DIR "C:/program Files/ImageMagick-6.7.1-Q16";  set ::_SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}]
  if { ![ok_twapi::verify_singleton_running "interlace at $spm::EX_LENS_LPI lpi"] }  {
    ::spm::start_spm .
  }
  set listAll [glob -nocomplain -directory "FIXED/SBS" "*.TIF"]
  set listOne [lindex $listAll 0]
  ::spm::interlace_listed_stereopairs_at_integer_lpi SBS $listAll $outDir \
            $spm::EX_LENS_LPI $spm::EX_PRINT_DPI $spm::EX_PRINT_WD
}


proc ::spm::ex__MIIX320_interlace {{outDir "IL"}}  {
  source c:/Work/Code/Auto/auto_spm/SPM_TCL/spm_sample_cmd.tcl
  #set ::_IM_DIR "c:/program files/ImageMagick-7.0.8-10";    set ::_SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
  if { ![ok_twapi::verify_singleton_running "interlace at $spm::EX_LENS_LPI lpi"] }  {
    ::spm::start_spm .
  }
  set listAll [glob -nocomplain -directory "FIXED/SBS" "*.TIF"]
  set listOne [lindex $listAll 0]
  ::spm::interlace_listed_stereopairs_at_integer_lpi SBS $listAll $outDir \
            $spm::EX_LENS_LPI $spm::EX_PRINT_DPI $spm::EX_PRINT_WD
}


