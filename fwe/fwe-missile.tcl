set lock_ban_nick ""
set lock_ban_modes ""
set launchcode_nr 2

#set cusers [chanlist $chan]
#set testhost [getchanhost $locked_nick $chan]

#####

setudef flag artstrike

set as_debug 1
set lock_ban_nick [string tolower $lock_ban_nick]
set lockactive 0
set locked_nick ""
set lockchan ""
set launchcode ""
set tries 0
set missiletimer ""

set lock_ban_nick [split $lock_ban_nick]

bind pub -|- !art artstrike:test
bind pub -|- !lock artstrike:lock
bind pub -|- !override artstrike:override
bind nick -|- * artstrike:nickchange 

proc as_not {nick msg} { putserv "NOTICE $nick :$msg" }
proc as_msg {nick msg} { putserv "PRIVMSG $nick :$msg" }
proc as_chan {chan msg} { putserv "PRIVMSG $chan :$msg" }
proc as_debug {msg} { 
	global as_debug
	if {$as_debug == 1} { putlog "artstrike: $msg" } 
	}

proc artstrike:nickchange {nick uhost hand chan newnick} {
		global locked_nick lockactive launchcode tries missiletimer lockchan
		 if { $lockactive > 0 && [string tolower $locked_nick] == [string tolower $nick]} {
		 set locked_nick $newnick
		 as_chan $lockchan "Lock reinstated. You can run but you can't hide, $newnick."
		 }
}

proc artstrike:test {nick uhost hand chan arg} {
		 set cusers [chanlist $chan]
		 set nusers {}
		 foreach x $cusers {
					if {[isop $x $chan]} {
						set x "1$x"
  				} elseif {[isvoice $x $chan]} {
					  set x "2$x"
					} else {
					  set x "3$x"
				  }
					lappend nusers $x
		 }
		 
		 set nusers [lsort -dictionary $nusers]
		 
		 set cusers {}
		 foreach x $nusers {
		 				 lappend cusers [string range $x 1 end]
		 } 	
		 #set nickindex [lsearch -exact $cusers $testnick]
		 #set nick2index [expr $nickindex+1]
		 #set nick2index [expr $nickindex-1]
		 putlog "test: [lrange $cusers 0 end]"
		 #putlog "test: [lindex $cusers 3]"
		 
}

proc artstrike:isallowed { nick } {
		 global lock_ban_nick botnick
		 if { [lsearch -exact $lock_ban_nick [string tolower $nick]] >= 0 || [string tolower $nick] == [string tolower $botnick] } {
		 		return 1
		 } else { 
		 	  return 0
		 }  
}

proc artstrike:reset {} {
		 global locked_nick lockactive launchcode tries missiletimer lockchan
		 set lockactive 0
		 set launchcode ""
		 set locked_nick ""
		 set lockchan ""
		 set tries 0
}

proc artstrike:lock {nick uhost hand chan arg} {
		global locked_nick lockactive launchcode tries missiletimer lockchan
		 if { $lockactive != 0 } { 
		 		as_chan $chan "I already have a lock on $locked_nick."
		 		return 0
		 }
		 set locked_nick [lindex [split $arg] 0]
		 if { [artstrike:isallowed $locked_nick] == 1 || [onchan $locked_nick $chan] == 0 } { 
		 		as_debug "Sorry can't get a lock on $locked_nick."
		 		as_chan $chan "Sorry I can't get a lock on $locked_nick"
				artstrike:reset
		 return 0 
		 }
		 set lockchan $chan
		 set lockactive 1
		 set tries 5
		 set launchcode [split "[rand 10] [rand 10] [rand 10]"]
		 set launchtime [expr [rand 40]+25]
		 as_chan $chan "Homing Missile Launch initiated... Target:\002\0034 $locked_nick\003\002."
		 as_chan $chan "$locked_nick has \002\[$tries\]\002 tries within \002\[$launchtime\]\002 seconds to abort the launch."
		 as_not $locked_nick "Use:\002 !override <3 digit code> \002 to abort the launch. ea. !override 123."
		 
		 set missiletimer [utimer $launchtime "artstrike:launch $chan 0"]
}

proc artstrike:impact { chan deltimer  } {
		 global locked_nick lockactive launchcode tries missiletimer
		 as_debug "impact!"
		 if { $deltimer } {
		     killutimer $missiletimer
  	 }
		 		 
		 set cusers [chanlist $chan]
		 set nusers {}
		 foreach x $cusers {
					if {[isop $x $chan]} {
						set x "1$x"
  				} elseif {[isvoice $x $chan]} {
					  set x "2$x"
					} else {
					  set x "3$x"
				  }
					lappend nusers $x
		 }
		 
		 set nusers [lsort -dictionary $nusers]
		 
		 set cusers {}
		 foreach x $nusers {
		 				 lappend cusers [string range $x 1 end]
		 } 	

		 set nickindex [lsearch -exact $cusers $locked_nick]
		 set nick2index [expr $nickindex+1]
		 set nick3index [expr $nickindex-1]
		 
		 set usercount [llength $cusers]
		 set nick2 [lindex $cusers $nick2index]
		 set nick3 [lindex $cusers $nick3index]
		  
		 artstrike:victim $chan "$locked_nick" "<<<<<<<<BLAAAAAAAAAAAAAAASSSSSSSSSST!!>>>>>>>>" "a dark shadow casts over $locked_nick ..."
		 if { $nick2index > -1 && $nick2index < $usercount && [artstrike:isallowed $nick2] != 1 } {
		  as_debug "$nick2index: $nick2"
			artstrike:victim $chan "$nick2" "<<<<<<<<BLAAAAAAAAAAAAAAASSSSSSSSSST!!>>>>>>>> You were in the blast radius of $locked_nick\'s impact." "$nick2 takes one last look at where $locked_nick used to be ..."  
			}
 	   if { $nick3index > -1 && $nick3index < $usercount && [artstrike:isallowed $nick3] != 1 } { 
			as_debug "$nick3index: $nick3"		
			artstrike:victim $chan "$nick3" "<<<<<<<<BLAAAAAAAAAAAAAAASSSSSSSSSST!!>>>>>>>> You were in the blast radius of $locked_nick\'s impact." "$nick3 feels uncomfortable ..."
		 }		 
		 artstrike:reset		  
}

proc artstrike:victim { chan nick reason text } {
		as_chan $chan $text
		as_debug "kicking $nick on $chan"
		putserv "KICK $chan $nick :$reason"
}

proc artstrike:launch { chan deltimer } {
		 global locked_nick lockactive launchcode tries missiletimer
		 set lockactive 2
		 
		 if { $deltimer } {
		    killutimer $missiletimer
  	 }
		 
		 set impacttime [expr [rand 30]+40]
		 as_not $locked_nick "You failed! Now take some people with ya!"
		 as_chan $chan "Homing missile launched! Target: $locked_nick. Estimated time of impact: \002\[$impacttime\]\002 seconds."
		 as_chan $chan "Users next to $locked_nick in the userlist will be killed in the blast radius."
		 as_chan $chan "Advise: Change your nick! Unfortunately $locked_nick will stay locked."
		 as_debug "MissileTimer set to $impacttime seconds"
		 set missiletimer [utimer $impacttime "artstrike:impact $chan 0"]
	 
}

proc artstrike:override {nick uhost hand chan arg} {
		global locked_nick lockactive launchcode tries missiletimer
		 if { $lockactive == 1 && [string tolower $locked_nick] == [string tolower $nick]} {
		 		set override_value [lindex [split $arg] 0]
				
				set ov1 [string index $override_value 0]
				set ov2 [string index $override_value 1]
				set ov3 [string index $override_value 2]
				
				if { $ov1 == [lindex $launchcode 0] } { 
					set ov1 "\0033\[$ov1\]\003"
				} else { if { $ov1 == [lindex $launchcode 1] || $ov1 == [lindex $launchcode 2] } {
					set ov1 "\0037\[$ov1\]\003"
				} else {
					set ov1 "\0034\[$ov1\]\003"
				} 
				}
				if { $ov2 == [lindex $launchcode 1] } { 
					set ov2 "\0033\[$ov2\]\003"
				} else { if { $ov2 == [lindex $launchcode 0] || $ov2 == [lindex $launchcode 2] } {
					set ov2 "\0037\[$ov2\]\003"
				} else {
					set ov2 "\0034\[$ov2\]\003"
				}
				}
				if { $ov3 == [lindex $launchcode 2] } { 
					set ov3 "\0033\[$ov3\]\003"
				} else {
				    if { $ov3 == [lindex $launchcode 0] || $ov3 == [lindex $launchcode 1] } {
    					set ov3 "\0037\[$ov3\]\003"
		     		} else {
					    set ov3 "\0034\[$ov3\]\003"
     				}
				}
				
			  if {$override_value == "[lindex $launchcode 0][lindex $launchcode 1][lindex $launchcode 2]"} { 
					 as_chan $chan "Code accepted. Launch aborted."
					 killutimer $missiletimer
					 artstrike:reset
				} else {
					set tries [expr $tries - 1]
					switch $tries {
					 0 { 
					 artstrike:launch $chan 1
					 }
					 1 { as_chan $chan "Incorrect Override Code: $ov1$ov2$ov3 (you have ONE try left!)" }
					 default {as_chan $chan "Incorrect Override Code: $ov1$ov2$ov3 (you have $tries tries left)"}
					 }
				}		
		 }
}

putlog "Missile Game 1.0.1 by bS loaded."

