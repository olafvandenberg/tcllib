package_version 1.7.0.1
package_name    tcllib

dist_exclude    config
dist_exclude    modules/ftp/example
dist_exclude    modules/ftpd/examples
dist_exclude    modules/stats
dist_exclude    modules/fileinput

critcl_main tcllibc   tcllibc.tcl
critcl      base64c   {base64/base64c.tcl base64/uuencode.tcl base64/yencode.tcl}
critcl      crcc      {crc/crcc.tcl crc/sum.tcl crc/crc32.tcl}
critcl      md4c      md4/md4c.tcl
critcl      md5c      md5/md5c.tcl
critcl      md5cryptc md5crypt/md5cryptc.tcl
critcl      rc4c      rc4/rc4c.tcl
critcl      sha1c     sha1/sha1c.tcl
critcl      uuid      uuid/uuid.tcl
critcl_notes {Note: you can ignore warnings for tcllibc.tcl, base64c.tcl and crcc.tcl.}
