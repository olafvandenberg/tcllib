###
# Class to deliver Static content
# When utilized, this class is fed a local filename
# by the dispatcher
###
::clay::define ::httpd::content.file {

  method FileName {} {
    # Some dispatchers will inject a fully qualified name during discovery
    if {[my clay exists FILENAME] && [file exists [my clay get FILENAME]]} {
      return [my clay get FILENAME]
    }
    set uri [string trimleft [my request get REQUEST_PATH] /]
    set path [my clay get path]
    set prefix [my clay get prefix]
    set fname [string range $uri [string length $prefix] end]
    if {$fname in "{} index.html index.md index index.tml"} {
      return $path
    }
    if {[file exists [file join $path $fname]]} {
      return [file join $path $fname]
    }
    if {[file exists [file join $path $fname.md]]} {
      return [file join $path $fname.md]
    }
    if {[file exists [file join $path $fname.html]]} {
      return [file join $path $fname.html]
    }
    if {[file exists [file join $path $fname.tml]]} {
      return [file join $path $fname.tml]
    }
    return {}
  }

  method DirectoryListing {local_file} {
    set uri [string trimleft [my request get REQUEST_PATH] /]
    set path [my clay get path]
    set prefix [my clay get prefix]
    set fname [string range $uri [string length $prefix] end]
    my puts [my html_header "Listing of /$fname/"]
    my puts "Listing contents of /$fname/"
    my puts "<TABLE>"
    if {$prefix ni {/ {}}} {
      set updir [file dirname $prefix]
      if {$updir ne {}} {
        my puts "<TR><TD><a href=\"/$updir\">..</a></TD><TD></TD></TR>"
      }
    }
    foreach file [glob -nocomplain [file join $local_file *]] {
      if {[file isdirectory $file]} {
        my puts "<TR><TD><a href=\"[file join / $uri [file tail $file]]\">[file tail $file]/</a></TD><TD></TD></TR>"
      } else {
        my puts "<TR><TD><a href=\"[file join / $uri [file tail $file]]\">[file tail $file]</a></TD><TD>[file size $file]</TD></TR>"
      }
    }
    my puts "</TABLE>"
    my puts [my html_footer]
  }

  method content {} {
    my variable reply_file
    set local_file [my FileName]
    if {$local_file eq {} || ![file exist $local_file]} {
      my log httpNotFound [my request get REQUEST_PATH]
      my error 404 {File Not Found}
      tailcall my DoOutput
    }
    if {[file isdirectory $local_file] || [file tail $local_file] in {index index.html index.tml index.md}} {
      ###
      # Produce an index page
      ###
      set idxfound 0
      foreach name {
        index.html
        index.tml
        index.md
        content.htm
      } {
        if {[file exists [file join $local_file $name]]} {
          set idxfound 1
          set local_file [file join $local_file $name]
          break
        }
      }
      if {!$idxfound} {
        tailcall my DirectoryListing $local_file
      }
    }
    switch [file extension $local_file] {
      .md {
        package require Markdown
        my reply set Content-Type {text/html; charset=UTF-8}
        set mdtxt  [::fileutil::cat $local_file]
        my puts [::Markdown::convert $mdtxt]
      }
      .tml {
        my reply set Content-Type {text/html; charset=UTF-8}
        set tmltxt  [::fileutil::cat $local_file]
        set headers [my request dump]
        dict with headers {}
        my puts [subst $tmltxt]
      }
      .svgz -
      .svg {
        # FU magic screws it up
        my reply set Content-Type {image/svg+xml}
        set reply_file $local_file
      }
      default {
        ###
        # Assume we are returning a binary file
        ###
        my reply set Content-Type [::fileutil::magic::filetype $local_file]
        set reply_file $local_file
      }
    }
  }

  method Dispatch {} {
    my variable reply_body reply_file reply_chan chan
    try {
      my reset
      # Invoke the URL implementation.
      my content
    } on error {err errdat} {
      my error 500 $err [dict get $errdat -errorinfo]
      tailcall my DoOutput
    }
    if {$chan eq {}} return
    my wait writable $chan
    if {![info exists reply_file]} {
      tailcall my DoOutput
    }
    chan configure $chan  -translation {binary binary}
    my log HttpAccess {}
    ###
    # Return a stream of data from a file
    ###
    set size [file size $reply_file]
    my reply set Content-Length $size
    append result [my reply output] \n
    chan puts -nonewline $chan $result
    set reply_chan [open $reply_file r]
    my ChannelRegister $reply_chan
    my log SendReply [list length $size]
    ###
    # Output the file contents. With no -size flag, channel will copy until EOF
    ###
    chan configure $reply_chan -translation {binary binary} -buffersize 4096 -buffering full -blocking 0
    my ChannelCopy $reply_chan $chan -chunk 4096
  }
}
