###
# Systemwide functions for tool
###

namespace eval ::tool {}

###
# topic: a92cd258900010f656f4c6e7dbffae57
###
proc ::tool::dynamic_methods class {
  set metadata [::oo::meta::metadata $class]
  ::tool::dynamic_methods_ensembles $class $metadata
  ::tool::dynamic_methods_class    $class $metadata
  #::tool::dynamic_methods_property $class $metadata
}

proc ::tool::object_create objname {
  foreach varname {
    object_info
    object_signal
    object_subscribe
    object_coroutine
  } {
    variable $varname
    set ${varname}($objname) {}
  }
  set object_info($objname) [list class [info object class $objname]]
}

proc ::tool::object_destroy objname {
  ::tool::event::generate $objname object_destroy [list objname $objname]

  variable coroutine_object
  foreach {coro coro_objname} [array get coroutine_object] {
    if { $objname eq $coro_objname } {
      coroutine_unregister $coro
    }
  }
  foreach varname {
    object_info
    object_signal
    object_subscribe
    object_coroutine
  } {
    variable $varname
    unset ${varname}($objname)
  }
}

proc ::tool::coroutine_register {objname coroutine} {
  variable all_coroutines
  variable object_coroutines
  variable coroutine_object
  # Wake a sleeping main loop
  set ::tool::wake_up 2
  if {$coroutine in $all_coroutines} {
    return 1
  }

  lappend all_coroutines $coroutine
  lappend object_coroutines($objname) $coroutine
  set coroutine_object($coroutine) $objname
  return 0
}

proc ::tool::coroutine_unregister {coroutine} {
  variable all_coroutines
  variable object_coroutines
  variable coroutine_object
  ldelete all_coroutines $coroutine
  if {[info exists coroutine_object($coroutine)]} {
    set objname $coroutine_object($coroutine)
    ldelete object_coroutines($objname) $coroutine
    unset coroutine_object($coroutine)
  }
}

proc ::tool::do_events {} {
  # Process coroutines
  variable all_coroutines
  set count 0
  foreach coro $all_coroutines {
    if {[info command $coro] eq {}} {
      #puts "$coro quit"
      coroutine_unregister $coro
      continue
    }
    #puts [list RUN $coro]
    try $coro on return {} {
      # Terminate the coroutine
      coroutine_unregister $coro
    } on break {} {
      # Terminate the coroutine
      coroutine_unregister $coro
    } on error {} {
      # Coroutine encountered an error
      coroutine_unregister $coro
      puts "ERROR $coro"
      puts "$::errorInfo"
    } on continue {result opts} {
      # Ignore continue
      if { $result eq "done" } {
        incr count
        coroutine_unregister $coro
      }
    } on ok {result opts} {
      if { $result eq "done" } {
        coroutine_unregister $coro
      } else {
        incr count
      }
    }
  }
  return $count
}

proc ::tool::main {} {
  package require cron 1.2
  ###
  # Have the cron::wake procedure wake up an idle loop instead
  # of it's normal run commands in the background
  ###
  proc ::cron::wake {} {
    set ::tool::wake_up 1
  }

  set ::forever 1
  while {$::forever} {
    incr ::tool::loops(all)
    if {[info command ::CRON] eq {}} {
      coroutine ::CRON ::cron::runTasksCoro
    }
    set cron_delay [::CRON]
    set tool_running [::tool::do_events]
    if {$cron_delay==0 || $tool_running>0} {
      incr ::tool::loops(active)
      update
    } else {
      incr ::tool::loops(idle)
      set ::tool::wake_up 0
      after [expr {$cron_delay*1000}] {set ::tool::wake_up 1}
      vwait ::tool::wake_up
    }
  }
}

namespace eval ::tool {
  variable trace 0
  variable all_coroutines
  if {![info exists all_coroutines]} {
    set all_coroutines {}
  }
}