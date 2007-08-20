setudef flag grenade

### Configuration
namespace eval fwe {
  namespace eval grenade {
	  # Command Prefix
	  variable command_char "!"
	  variable debug 0 
	  
	  # Binds
	  variable binds_grenade "grenade"
	  variable binds_pickup "pickup"
	  variable binds_throw "throw"
	  variable banned_nicks "L Q"
  }
}
### END CONFIGURATION

### START SCRIPT
namespace eval fwe {
  namespace eval grenade {
	  variable version "fwe:grenade-1.0"
	  variable running
	  variable victim
	  variable carrier
	  variable gtimer
  }
}

bind pubm -|- "*" fwe::grenade::pub_commands

namespace eval fwe {
  namespace eval grenade {
	 
	  proc pub_commands {nick uhand hand chan input} {
		if {[lsearch -exact [channel info $chan] +grenade] != -1} {
		  controller "$input" "$chan" "$nick" "$uhand" "$hand"
		}
	  }
	  
	  proc controller {input chan nick uhand hand} {
		  if {[encoding system] != "identity" && [lsearch [encoding names] "ascii"]} {
			set command_char [encoding convertfrom ascii ${fwe::grenade::command_char}]
			set input [encoding convertfrom ascii $input]
		  } elseif {[encoding system] == "identity"} {
			set command_char [encoding convertfrom identity ${fwe::grenade::command_char}]
			set input [encoding convertfrom identity $input]
		  } else {
			set command_char ${fwe::grenade::command_char}
		  }
		  
		  #Specifically retrieve only ONE (ascii) character, then check that matches the command_char first
		  set trigger_char [string index $input 0]
		  if {[encoding system] == "identity"} {
			set trigger_char [encoding convertfrom identity $trigger_char]
		  }
	
		  #Sanity check 1 - If no match, stop right here. No need to match every (first word) of
		  # every line of channel data against every bind if the command_char doesnt even match.
		  if {$trigger_char != $command_char} {
			return
		  }
		  
		  set trigger [string range [lindex $input 0] 1 end]
		  set parameters [string trim [string range $input [string wordend $input 1] end]]
		  
		  dlog "$chan - trigger: $trigger"
		  dlog "$chan - parameters: $parameters"
		  dlog "$chan - nick: $nick"
		  dlog "$chan - uhand: $uhand"
		  dlog "$chan - hand: $hand"
		  
		  # Grenade
		  foreach bind [split $fwe::grenade::binds_grenade " "] {
			if {[string match -nocase $bind $trigger] == 1} {
				grenade $parameters $chan $nick $uhand $hand
			}
		  }
		  
		  # Pickup
		  foreach bind [split $fwe::grenade::binds_pickup " "] {
			if {[string match -nocase $bind $trigger] == 1} {
				pickup $parameters $chan $nick $uhand $hand
			}
		  }
		  
		  # Throw
		  foreach bind [split $fwe::grenade::binds_throw " "] {
			if {[string match -nocase $bind $trigger] == 1} {
				throw $parameters $chan $nick $uhand $hand
			}
		  }
	  }
	  
	  proc out_not {to msg} { putserv "NOTICE $to :$msg" }
	  proc out_msg {to msg} { putserv "PRIVMSG $to :$msg" }
  
	  proc dlog {msg} { 
		  if {$fwe::grenade::debug == 1} { putlog "$fwe::grenade::version: $msg" }
	  }
	  	  
	  proc isvalidtarget { chan target } {
		  dlog "$chan - target: $target"
		  if { [isallowed $target] == 0 || [onchan $target $chan] == 0} {
			  dlog "$chan - Invalid target. "
			  return 0
		   } else {
			  dlog "$chan - Valid target. "
			  return 1
		   }  
	  }
	  
	  proc isactive { chan } {
		  if {[info exists fwe::grenade::running($chan)]} {
		  if { $fwe::grenade::running($chan) == 1 } {
				dlog "$chan - Active"
				return 1
			 } else {
				dlog "$chan - Not Active"
				return 0
			 } 
		  } else {
			  dlog "$chan - Not Active"
			  return 0
		  }
	  }
	  
	  proc isvictim { chan nick } {
				if { $fwe::grenade::victim($chan) == $nick } {
					  return 1
				   } else {
					  return 0
				   }   
			}
	  
	  proc iscarrier { chan nick } {
					  if { $fwe::grenade::carrier($chan) == $nick } {
							return 1
						 } else {
							return 0
						 }   
				  }
	  
	  proc activate { chan target } {
		  set fwe::grenade::running($chan) 1
		  set fwe::grenade::victim($chan) $target
		  set fwe::grenade::carrier($chan) ""
		  set xtime [expr [rand 45]+15]
		  set fwe::grenade::gtimer [utimer $xtime "fwe::grenade::detonate $chan"]
		  dlog "$chan - Grenade activated"
		  dlog "$chan - Timer: $xtime"
	  }
	  
	  proc deactivate { chan } {
		  set fwe::grenade::running($chan) 0
		  set fwe::grenade::victim($chan) ""
		  set fwe::grenade::carrier($chan) ""
	  }
	  
	  proc grenade { input chan nick uhand hand } {
		 set target $input
		 if { [isactive $chan] == 0 } {
			 if { [isvalidtarget $chan $target] } {
				activate $chan $target
				out_msg $chan "... a grenade drops before $target\`s feet ... what to do.. what to do..."
			 } else {
				out_not $nick "$target is not a valid target."
			 }
		 } else {
			 out_not $nick "There already is a primed grenade on this channel." 
		 }
		  
	  }
	  
	  proc change { chan target } {
		  set thrower $fwe::grenade::carrier($chan)
		  set fwe::grenade::carrier($chan) ""
		  out_msg $chan "$thrower throws the grenade in the direction of $target ..."
		  if { [isvalidtarget $chan $target] } {
			  set fwe::grenade::victim($chan) $target
			  set newtarget $target
		  } else {
			  set newtarget $thrower
			  out_msg $chan "... a sudden breeze of wind changes the grenades direction..."
		  }
		  out_msg $chan "$newtarget notices the grenade dropping before his feet..."
	  }
	  
	  proc pickup { input chan nick uhand hand } {
		  if { [isactive $chan] && [isvictim $chan $nick] && [iscarrier $chan $nick] == 0 } {
			  
			  if { [expr [rand 3]] != 2 } {
			  	set fwe::grenade::carrier($chan) $nick
			  	out_msg $chan "$nick heroically picks up the primed grenade ..."
		  		} else {
				out_msg $chan "$nick tries to pickup the grenade but fails."
		  		}	  
		  }
	  }
	  
	  proc throw { input chan nick uhand hand } {
		    if { [isactive $chan] && [isvictim $chan $nick] && [iscarrier $chan $nick]} {
				set target $input
				change $chan $target
			}		
	  }
	  
	  proc detonate { chan } {
		 set victim $fwe::grenade::victim($chan)
		 dlog "$chan - BOOM!"
		 putserv "KICK $chan $victim :BOOM!! a grenade just exploded in your face."
		 deactivate $chan  
	  }
	  
	  
	  proc isallowed { nick } {
		   set bnicks [string tolower $fwe::grenade::banned_nicks]
		   if { [lsearch -exact $bnicks [string tolower $nick]] >= 0 || [string tolower $nick] == [string tolower $::botnick] } {
				return 0
		   } else { 
				return 1
		   }  
	  }
	  
  }
}
### END SCRIPT

putlog "$fwe::grenade::version loaded."
  