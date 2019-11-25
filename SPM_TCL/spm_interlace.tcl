# spm_interlace.tcl

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors
#package require twapi_clipboard

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "common.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "disk_info.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]


namespace eval ::spm:: {
}


# The procedure:
### assumptions:
### - "Image direction (from left to right)" checkbox is checked 
### - "Create slit animation image" checkbox is not checked 
# (delete "TMP_FRAME_l.TIF", "TMP_FRAME_r.TIF" to avoid popup)
# - Open the stereopair
# (delete "TMP_FRAME_l.TIF", "TMP_FRAME_r.TIF" to avoid popup)
# - Save as left- and right images - "TMP_FRAME_l.TIF", "TMP_FRAME_r.TIF" - by Ctrl-S
# Open "Create lenticular image" - by Edit -> 5 * {UP}
# Focus filename field by Alt-N and type: "TMP_FRAME_l.TIF" "TMP_FRAME_r.TIF"
# Fill fields "Lenticular Lens Pitch", "Printer Resolution", "Print Width" from call parameters using tabstop traversal
# Press TAB until "Create With Selected Files" reached and press SPACE

# TODO
