# polynomial_fit.tcl - Find an approximating polynomial of known degree for a given data.
# ---------------------------------------------------------
# Example: For input data:
# x = {0,  1,  2,  3,  4,  5,  6,   7,   8,   9,   10};
# y = {1,  6,  17, 34, 57, 86, 121, 162, 209, 262, 321};
# The approximating polynomial is:  3*x^2 + 2*x + 1
# Here, the polynomial's coefficients are (3, 2, 1). 
# ---------------------------------------------------------
# https://rosettacode.org/wiki/Polynomial_regression
# https://rosettacode.org/wiki/Polynomial_regression#Tcl

################################################################################
## Install tcllib into ...auto_spm\SPM_TCL\tcllib\
################################################################################
##   (download from https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md)
## "C:\Program Files\TWAPI\tclkit-gui-8_6_9-twapi-4_3_7-x64-max.exe"  ./installer.tcl  -app-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -example-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -html-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -nroff-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -pkg-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib
################################################################################

set UTIL_DIR [file dirname [info script]]
source [file join $UTIL_DIR "debug_utils.tcl"]

if { -1 == [lsearch -glob $auto_path  "*/tcllib"] } {
  lappend auto_path [file join $UTIL_DIR ".." "tcllib"]
}

#~ namespace eval ::ok_utils:: {

    #~ namespace export \
    
#~ }


package require math::linearalgebra
 
proc build.matrix {xvec degree} {
    set sums [llength $xvec]
    for {set i 1} {$i <= 2*$degree} {incr i} {
        set sum 0
        foreach x $xvec {
            set sum [expr {$sum + pow($x,$i)}] 
        }
        lappend sums $sum
    }
 
    set order [expr {$degree + 1}]
    set A [math::linearalgebra::mkMatrix $order $order 0]
    for {set i 0} {$i <= $degree} {incr i} {
        set A [math::linearalgebra::setrow A $i [lrange $sums $i $i+$degree]]
    }
    return $A
}
 
proc build.vector {xvec yvec degree} {
    set sums [list]
    for {set i 0} {$i <= $degree} {incr i} {
        set sum 0
        foreach x $xvec y $yvec {
            set sum [expr {$sum + $y * pow($x,$i)}] 
        }
        lappend sums $sum
    }
 
    set x [math::linearalgebra::mkVector [expr {$degree + 1}] 0]
    for {set i 0} {$i <= $degree} {incr i} {
        set x [math::linearalgebra::setelem x $i [lindex $sums $i]]
    }
    return $x
}
 
# Now, to solve the example from the top of this page
set x {0   1   2   3   4   5   6   7   8   9  10}
set y {1   6  17  34  57  86 121 162 209 262 321}
 
# build the system A.x=b
set degree 2
set A [build.matrix $x $degree]
set b [build.vector $x $y $degree]
# solve it
set coeffs [math::linearalgebra::solveGauss $A $b]
# show results
puts $coeffs