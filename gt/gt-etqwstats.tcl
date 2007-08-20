###############################################################################
#
#	Enemy Territory: Quake Wars Stats 
#	
#	File:		gt-etqwstats.tcl
#	Date:		2007-08-08		
#	Version:	0.9
#	Author(s):	Armand `bS` Pondman <bs@zerobarrier.nl>
#	
#	Tested on:	
#	- Eggdrop 1.6.18 GNU/LINUX with Tcl 8.4 + tDOM 0.8.0 (http://www.tdom.org/)
#
#	Setup:
#
#	*
#
#	Usage:
#
#	*
#	
#	History:
#   
#	0.9 (2007-08-08): initial beta release
#
#	TODO:
#
#	*
#
#
### START CONFIGURATION 

namespace eval ::etqws {
	  
	# Announce on join? 1=on, 0=off
	variable announce 1
	# Allow public response option? 1=on, 0=off
	variable allow_public 1
	# ETQW Profile stats URL
	variable url_profile "http://stats.enemyterritory.com/profile/@@NICK@@?xml=true"
	# Command Prefix
    variable command_char "!"
	# Maximum chars for each line
	variable split_length "443"
	# Debug, 1=on, 0=off  
	variable debug 1 
	# Binds
	variable binds_stats "etqwstats"
}

### END CONFIGURATION

### START SCRIPT

setudef flag etqwstats

namespace eval ::etqws {
	 variable version "ETQW Stats v0.9"
	 variable author "Armand `bS` Pondman (bs@zerobarrier.nl)"
}

namespace eval etqws {

	  ### Init
	  proc init {} {
		  package require http
		  package require tdom
		  bind join -|- * [namespace current]::announce
		  bind pubm -|- "*" [namespace current]::pub_commands
		  bind evnt -|- prerehash [namespace current]::shutdown
		  putlog "$::etqws::version by $::etqws::author loaded."
	  }
	  
	  ### Cleanup
	  proc shutdown {args} {
		  catch {unbind evnt -|- prerehash [namespace current]::shutdown}
		  catch {unbind pubm -|- "*" [namespace current]::pub_commands}
		  catch {unbind join -|- * [namespace current]::announce}
		  namespace delete [namespace current]
	  }
	  
	  proc chancheck { chan } {
		  return [lsearch -exact [channel info $chan] +etqwstats]
	  }
	
	  proc pub_commands {nick uhand hand chan input} {
		if {[chancheck $chan] != -1} {
		  pub_dispatch "$input" "$chan" "$nick" "$uhand" "$hand"
		}
	  }
	  
	  proc pub_dispatch {input chan nick uhand hand} {
		  if {[encoding system] != "identity" && [lsearch [encoding names] "ascii"]} {
			set command_char [encoding convertfrom ascii ${::etqws::command_char}]
			set input [encoding convertfrom ascii $input]
		  } elseif {[encoding system] == "identity"} {
			set command_char [encoding convertfrom identity ${::etqws::command_char}]
			set input [encoding convertfrom identity $input]
		  } else {
			set command_char ${::etqws::command_char}
		  }

		  set trigger_char [string index $input 0]
		  if {[encoding system] == "identity"} {
			set trigger_char [encoding convertfrom identity $trigger_char]
		  }
		  if {$trigger_char != $command_char} {
			return
		  }
		  
		  set trigger [string range [lindex $input 0] 1 end]
		  set parameters [string trim [string range $input [string wordend $input 1] end]]
		  
		  #dlog "$chan - trigger: $trigger"
		  #dlog "$chan - parameters: $parameters"
		  #dlog "$chan - nick: $nick"
		  #dlog "$chan - uhand: $uhand"
		  #dlog "$chan - hand: $hand"
		  
		  # Main Stats
		  foreach bind [split $::etqws::binds_stats " "] {
			  if {[string match -nocase $bind $trigger] == 1} {
				statsController $parameters $chan $nick $uhand $hand
			}
		  }

		  
	  }
	  
	  proc out_not {to msg} { putserv "NOTICE $to :$msg" }
	  proc out_msg {to msg} { putserv "PRIVMSG $to :$msg" }

	  proc dlog {msg} { 
		  if {$::etqws::debug == 1} { putlog "$::etqws::version: $msg" }
	  }
	  
	  proc announce { nick uhost hand chan } {
		  if { $nick!=$::botnick && $::etqws::announce == 1 } {
			out_not $nick "For help on showing your ETQW stats on IRC use: $::etqws::command_char$::etqws::binds_stats"
		  }  
	  }
	  
	  proc help { nick } {
		 out_not $nick "\002usage: $::etqws::command_char$::etqws::binds_stats\002 <\002nickname\002> (\002public\002)"
	  }
	
	proc statsController { input chan nick uhand hand } {
		
		# Help
		if { $input=="" } {
			help $nick
			return 0
		}
		
		set nickname [lindex [split $input] 0]
		set optionA [lindex [split $input] 1]
		set optionB [lindex [split $input] 2]
		set optionC [lindex [split $input] 3]
		set public [lindex [split $input] end]
		
		getStatsDom $nick $chan $nickname root
			
		# Modes
		switch $optionA {
			"class" { statsClass $root $optionB $nick queue }
			"weapons" { statsWeapons $root $optionB $nick queue }
			# Default / Profile
			default { statsDefault $root queue }
		}
		
		# Output queue
		catch {
			foreach msg $queue {
			   foreach line [line_wrap $msg] {
					if { $public == "public" && $::etqws::allow_public } {
					 out_msg $chan $line
					  } else {
					 out_not $nick $line
					  }
			   }
			 }
		}
	
	}
	
	proc getStatsDom { nick chan nickname docroot } {
		upvar $docroot root
		
		regsub -nocase -all "@@NICK@@" $::etqws::url_profile $nickname xmlsource
		
		#dlog "url: $xmlsource"
		dlog "Fetching stats for $nickname requested by $nick on $chan."
		
		set page [::http::data [::http::geturl $xmlsource]]
		set doc [dom parse -simple $page]
		set root [$doc documentElement]
	}
	
    proc statsWeapons { root weapon nick output } {
		upvar $output queue
		
		getStatsNames $root "//weapons" wlist
		set wlist [lsort -dictionary $wlist]
		#dlog "weapons($weapon) : [lsearch -exact $wlist $weapon]"
		#[join [split $data] " \002"]
				
		if { [lsearch -exact $wlist "$weapon"] > -1 } {
			get_stats $root "//weapons/$weapon" data
			get_stats $root "//user_info" user
			#dlog [array get data]
			foreach {stat value} [array get data] {
				lappend tmp $stat\_\002[fv $value]\002
			}
			lappend queue "weapon_\002\0035$weapon\003\002 ¤ \002\037$user(username)\037\002 ¤ [join $tmp " ¤ "]"
		} else {
			lappend tmp "\002Available weapons:\002 [join [split $wlist] " \002"]"
			lappend tmp "\002usage: $::etqws::command_char$::etqws::binds_stats\002 <\002nickname\002> \002weapons\002 <\002weapon\002> (\002public\002)"
			foreach msg $tmp {
				foreach line [line_wrap $msg] {
					out_not $nick $line
				}	
			}
		}	
    }
	
	proc statsClass { root class nick output } {
			upvar $output queue
			
			getStatsNames $root "//classes" clist
			set clist [lsort -dictionary $clist]
			#dlog "weapons($weapon) : [lsearch -exact $wlist $weapon]"
			#[join [split $data] " \002"]
					
			if { [lsearch -exact $clist "$class"] > -1 } {
				get_stats $root "//classes/$class" data
				get_stats $root "//user_info" user
				#dlog [array get data]
				foreach {stat value} [array get data] {
					lappend tmp $stat\_\002[fv $value]\002
				}
				lappend queue "class_\002\0035$class\003\002 ¤ \002\037$user(username)\037\002 ¤ [join $tmp " ¤ "]"
			} else {
				lappend tmp "\002Available classes:\002 [join [split $clist] " \002"]"
				lappend tmp "\002usage: $::etqws::command_char$::etqws::binds_stats\002 <\002nickname\002> \002class\002 <\002class\002> (\002public\002)"
				foreach msg $tmp {
					foreach line [line_wrap $msg] {
						out_not $nick $line
					}	
				}
			}	
		}
	
	  proc statsDefault { root output } {
		  upvar $output queue
		  
		  # Put the XML data into arrays for each defined section
		  get_stats $root "//user_info" data_ui
		  get_stats $root "//total" data_total
		  get_stats $root "//misc" data_misc
		  
		  #get_stats_child $root "//vehicles" data_vehicles
		  #get_stats_child $root "//tools" data_tools
		  #get_stats_child $root "//classes" data_class
		  #get_stats_child $root "//xp" data_xp
		  #get_stats_child $root "//deployables" data_deploy
		  
		  set won [expr {$data_misc(maps_won_gdf)+$data_misc(maps_won_strogg)}]
		  set lost [expr {$data_misc(maps_lost_gdf)+$data_misc(maps_lost_strogg)}]
		  if { $lost > 0 && $won > 0 } {
			  set wlr [expr { double($won) / double($lost)  } ]
		  } {
			set wlr $won  
		  }
 		  
		  set po [expr {$data_misc(gdf_primary_objective_destroyed)+$data_misc(gdf_primary_objective_constructed)+$data_misc(gdf_primary_objective_hacked)}]
		  
		  lappend queue "\002\0035$data_ui(military_rank)\003\002 ¤ \002$data_ui(username)\002 ¤ ranked_\0032\002$data_ui(rank)\003\002 ¤ xp_\002[format %.0f $data_total(xp)]\002 ¤ played_\002[gettime $data_total(time_played)]"
		  lappend queue "kills_\002$data_total(kills)\002 ¤ deaths_\002$data_total(deaths)\002 ¤ kdr_\002[format %.2f $data_total(kill_death_ratio)]\002 ¤ kpm_\002[format %.2f $data_total(kills_per_minute)]\002 ¤ accuracy_\002[format %.2f%% $data_total(accuracy)]"
		  lappend queue "won_\002$won\002 ¤ lost_\002$lost\002 ¤ wlr_\002[fv $wlr]\002 ¤ p.obj_\002$po"
	  }
     
	proc fv { value } {
		if { [string match "*\.*" $value] } {
			format %.2f $value
		} else {
			format $value
		}
	}
	
	proc get_stats { root xpath data_var} {
		set node [$root selectNodes $xpath]
		upvar $data_var data_array
		array set data_array {}
		foreach item [$node attributes] {
			set data_array($item) [$node getAttribute $item]
		}
	}
	
	 proc get_stats_child { root xpath data_var} {
		set node [$root selectNodes $xpath]
		upvar $data_var data_array
		array set data_array {}
		foreach item [$node childNodes] {
			set tmpnode [$item nodeName]
			set tmpattr [$item attributes]
			foreach atr $tmpattr {
			  set tmpvar [$item getAttribute $atr]
			  set data_array($tmpnode,$atr) $tmpvar
			}
		}
	 }
	
	proc getStatsNames { root xpath data_var} {
		set node [$root selectNodes $xpath]
		upvar $data_var data_list
		foreach item [$node childNodes] {
			lappend data_list [$item nodeName]
		}
	}
	
	 proc gettime { secs } {
		 set timeatoms [ list ]
		 if { [ catch {
			foreach div { 3600 60 1 } \
					mod { 0 60 60 } \
				   name { h m s } {
			   set n [ expr {$secs / $div} ]
			   if { $mod > 0 } { set n [ expr {$n % $mod} ] }
			   if { $n > 1 } {
				  lappend timeatoms "$n\002${name}\002"
			   } elseif { $n == 1 } {
				 lappend timeatoms "$n\002$name\002"
			   }
			}
		 } err ] } {
			return -code error "duration: $err"
		 }
		 return [join $timeatoms ":"]
	}
	
	proc line_wrap {str {splitChr { }}} {
		  set out [set cur {}]
		  set i 0
		  set len $::etqws::split_length
		  foreach word [split [set str][set str ""] $splitChr] {
			if {[incr i [string len $word]] > $len} {
			  lappend out [join $cur $splitChr]
			  set cur [list $word]
			  set i [string len $word]
			} else {
			  lappend cur $word
			}
			incr i
		  }
		  lappend out [join $cur $splitChr]
		}
	

}

### CALL INIT
::etqws::init

### END SCRIPT