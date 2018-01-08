
::oo::class create ::practcl::library {
  superclass ::practcl::project


  method clean {PATH} {
    set objext [my define get OBJEXT o]
    foreach {ofile info} [my project-compile-products] {
      if {[file exists [file join $PATH objs $ofile].${objext}]} {
        file delete [file join $PATH objs $ofile].${objext}
      }
    }
    foreach ofile [glob -nocomplain [file join $PATH *.${objext}]] {
      file delete $ofile
    }
    foreach ofile [glob -nocomplain [file join $PATH objs *]] {
      file delete $ofile
    }
    set libfile [my define get libfile]
    if {[file exists [file join $PATH $libfile]]} {
      file delete [file join $PATH $libfile]
    }
    my implement $PATH
  }

  method project-compile-products {} {
    set result {}
    foreach item [my link list subordinate] {
      lappend result {*}[$item project-compile-products]
    }
    set filename [my define get output_c]
    if {$filename ne {}} {
      ::practcl::debug [self] [self class] [self method] project-compile-products $filename
      set ofile [file rootname [file tail $filename]]_main
      lappend result $ofile [list cfile $filename extra [my define get extra] external [string is true -strict [my define get external]]]
    }
    return $result
  }


  method go {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set name [my define getnull name]
    if {$name eq {}} {
      set name generic
      my define name generic
    }
    if {[my define get tk] eq {@TEA_TK_EXTENSION@}} {
      my define set tk 0
    }
    set output_c [my define getnull output_c]
    if {$output_c eq {}} {
      set output_c [file rootname $name].c
      my define set output_c $output_c
    }
    set output_h [my define getnull output_h]
    if {$output_h eq {}} {
      set output_h [file rootname $output_c].h
      my define set output_h $output_h
    }
    set output_tcl [my define getnull output_tcl]
    #if {$output_tcl eq {}} {
    #  set output_tcl [file rootname $output_c].tcl
    #  my define set output_tcl $output_tcl
    #}
    #set output_mk [my define getnull output_mk]
    #if {$output_mk eq {}} {
    #  set output_mk [file rootname $output_c].mk
    #  my define set output_mk $output_mk
    #}
    set initfunc [my define getnull initfunc]
    if {$initfunc eq {}} {
      set initfunc [string totitle $name]_Init
      my define set initfunc $initfunc
    }
    set output_decls [my define getnull output_decls]
    if {$output_decls eq {}} {
      set output_decls [file rootname $output_c].decls
      my define set output_decls $output_decls
    }
    my variable links
    foreach {linktype objs} [array get links] {
      foreach obj $objs {
        $obj go
      }
    }
    ::practcl::debug [list /[self] [self method] [self class] -- [my define get filename] [info object class [self]]]
  }


  method generate-decls {pkgname path} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set outfile [file join $path/$pkgname.decls]

    ###
    # Build the decls file
    ## #
    set fout [open $outfile w]
    puts $fout [subst {###
  # $outfile
  #
  # This file was generated by [info script]
  ###

library $pkgname
interface $pkgname
}]

    ###
    # Generate list of functions
    ###
    set stubfuncts [my generate-stub-function]
    set thisline {}
    set functcount 0
    foreach {func header} $stubfuncts {
      puts $fout [list declare [incr functcount] $header]
    }
    puts $fout [list export "int [my define get initfunc](Tcl_Inter *interp)"]
    puts $fout [list export "char *[string totitle [my define get name]]_InitStubs(Tcl_Inter *interp, char *version, int exact)"]

    close $fout

    ###
    # Build [package]Decls.h
    ###
    set hout [open [file join $path ${pkgname}Decls.h] w]
    close $hout

    set cout [open [file join $path ${pkgname}StubInit.c] w]
    puts $cout [string map [list %pkgname% $pkgname %PkgName% [string totitle $pkgname]] {
#ifndef USE_TCL_STUBS
#define USE_TCL_STUBS
#endif
#undef USE_TCL_STUB_PROCS

#include "tcl.h"
#include "%pkgname%.h"

/*
** Ensure that Tdom_InitStubs is built as an exported symbol.  The other stub
** functions should be built as non-exported symbols.
*/

#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT

%PkgName%Stubs *%pkgname%StubsPtr;

 /*
 **----------------------------------------------------------------------
 **
 **  %PkgName%_InitStubs --
 **
 **        Checks that the correct version of %PkgName% is loaded and that it
 **        supports stubs. It then initialises the stub table pointers.
 **
 **  Results:
 **        The actual version of %PkgName% that satisfies the request, or
 **        NULL to indicate that an error occurred.
 **
 **  Side effects:
 **        Sets the stub table pointers.
 **
 **----------------------------------------------------------------------
 */

char *
%PkgName%_InitStubs (Tcl_Interp *interp, char *version, int exact)
{
  char *actualVersion;
  actualVersion = Tcl_PkgRequireEx(interp, "%pkgname%", version, exact,(ClientData *) &%pkgname%StubsPtr);
  if (!actualVersion) {
    return NULL;
  }
  if (!%pkgname%StubsPtr) {
    Tcl_SetResult(interp,"This implementation of %PkgName% does not support stubs",TCL_STATIC);
    return NULL;
  }
  return actualVersion;
}
}]
    close $cout
  }

  method implement path {
    my go
    my Collate_Source $path
    set errs {}
    foreach item [my link list dynamic] {
      if {[catch {$item implement $path} err errdat]} {
        lappend errs "Skipped $item: [$item define get filename] $err"
        if {[dict exists $errdat -errorinfo]} {
          lappend errs [dict get $errdat -errorinfo]
        } else {
          lappend errs $errdat
        }
      }
    }
    foreach item [my link list module] {
      if {[catch {$item implement $path} err errdat]} {
        lappend errs "Skipped $item: [$item define get filename] $err"
        if {[dict exists $errdat -errorinfo]} {
          lappend errs [dict get $errdat -errorinfo]
        } else {
          lappend errs $errdat
        }
      }
    }
    if {[llength $errs]} {
      set logfile [file join $::CWD practcl.log]
      ::practcl::log $logfile "*** ERRORS ***"
      foreach {item trace} $errs {
        ::practcl::log $logfile "###\n# ERROR\n###$item"
        ::practcl::log $logfile "###\n# TRACE\n###$trace"
      }
      ::practcl::log $logfile "*** DEBUG INFO ***"
      ::practcl::log $logfile $::DEBUG_INFO
      puts stderr "Errors saved to $logfile"
      exit 1
    }
    set cout [open [file join $path [my define get output_c]] w]
    puts $cout [subst {/*
** This file is generated by the [info script] script
** any changes will be overwritten the next time it is run
*/}]
    puts $cout [my generate-c]
    puts $cout [my generate-loader]
    close $cout

    set macro HAVE_[string toupper [file rootname [my define get output_h]]]_H
    set hout [open [file join $path [my define get output_h]] w]
    puts $hout [subst {/*
** This file is generated by the [info script] script
** any changes will be overwritten the next time it is run
*/}]
    puts $hout "#ifndef ${macro}"
    puts $hout "#define ${macro} 1"
    puts $hout [my generate-h]
    puts $hout "#endif"
    close $hout

    set output_tcl [my define get output_tcl]
    if {$output_tcl ne {}} {
      set tclout [open [file join $path [my define get output_tcl]] w]
      puts $tclout "###
# This file is generated by the [info script] script
# any changes will be overwritten the next time it is run
###"
      puts $tclout [my generate-tcl-pre]
      puts $tclout [my generate-tcl-loader]
      puts $tclout [my generate-tcl-post]
      close $tclout
    }
  }

  # Backward compadible call
  method generate-make path {
    my build-Makefile $path [self]
  }

  method install-headers {} {
    set result {}
    return $result
  }

  method linktype {} {
    return library
  }

  # Create a "package ifneeded"
  # Args are a list of aliases for which this package will answer to
  method package-ifneeded {args} {
    set result {}
    set name [my define get pkg_name [my define get name]]
    set version [my define get pkg_vers [my define get version]]
    if {$version eq {}} {
      set version 0.1a
    }
    set output_tcl [my define get output_tcl]
    if {$output_tcl ne {}} {
      set script "\[list source \[file join \$dir $output_tcl\]\]"
    } elseif {[string is true -strict [my define get SHARED_BUILD]]} {
      set script "\[list load \[file join \$dir [my define get libfile]\] $name\]"
    } else {
      # Provide a null passthrough
      set script "\[list package provide $name $version\]"
    }
    set result "package ifneeded [list $name] [list $version] $script"
    foreach alias $args {
      set script "package require $name $version \; package provide $alias $version"
      append result \n\n [list package ifneeded $alias $version $script]
    }
    return $result
  }


  method shared_library {{filename {}}} {
    set name [string tolower [my define get name [my define get pkg_name]]]
    set NAME [string toupper $name]
    set version [my define get version [my define get pkg_vers]]
    set map {}
    lappend map %LIBRARY_NAME% $name
    lappend map %LIBRARY_VERSION% $version
    lappend map %LIBRARY_VERSION_NODOTS% [string map {. {}} $version]
    lappend map %LIBRARY_PREFIX% [my define getnull libprefix]
    set outfile [string map $map [my define get PRACTCL_NAME_LIBRARY]][my define get SHLIB_SUFFIX]
    return $outfile
  }

  method static_library {{filename {}}} {
    set name [string tolower [my define get name [my define get pkg_name]]]
    set NAME [string toupper $name]
    set version [my define get version [my define get pkg_vers]]
    set map {}
    lappend map %LIBRARY_NAME% $name
    lappend map %LIBRARY_VERSION% $version
    lappend map %LIBRARY_VERSION_NODOTS% [string map {. {}} $version]
    lappend map %LIBRARY_PREFIX% [my define getnull libprefix]
    set outfile [string map $map [my define get PRACTCL_NAME_LIBRARY]].a
    return $outfile
  }
}
