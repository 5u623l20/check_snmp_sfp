#!/usr/bin/env perl
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2022 Moin Rahman

my $Version='1.0.0';

use strict;
use Data::Dump qw(dump);
use Getopt::Long;
use Net::SNMP;
use Class::Struct;

# Nagios specific
my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# SNMP Datas
my $descr_table = '1.3.6.1.2.1.2.2.1.2';
my $oper_table = '1.3.6.1.2.1.2.2.1.8.';
my $admin_table = '1.3.6.1.2.1.2.2.1.7.';
my $value_rx_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.5.';
my $value_bias_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.6.';
my $value_tx_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.7.';
my $value_temp_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.8.';
my $high_rx_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.9.';
my $low_rx_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.10.';
my $high_rx_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.11.';
my $low_rx_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.12.';
my $high_bias_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.13.';
my $low_bias_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.14.';
my $high_bias_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.15.';
my $low_bias_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.16.';
my $high_tx_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.17.';
my $low_tx_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.18.';
my $high_tx_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.19.';
my $low_tx_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.20.';
my $high_temp_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.21.';
my $low_temp_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.22.';
my $high_temp_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.23.';
my $low_temp_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.24.';
my $value_volt_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.25.';
my $high_volt_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.26.';
my $low_volt_alarm_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.27.';
my $high_volt_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.28.';
my $low_volt_warn_table = '1.3.6.1.4.1.2636.3.60.1.1.1.1.29.';

my %status=(1=>'UP',2=>'DOWN',3=>'TESTING',4=>'UNKNOWN',5=>'DORMANT',6=>'NotPresent',7=>'lowerLayerDown');

# Globals

# Standard options
my $o_host = 		undef; 	# hostname
my $o_port = 		161; 	# port
my $o_descr = 		undef; 	# description filter
my $o_help= 		undef; 	# wan't some help ?
my $o_verb=	    	undef;	# verbose mode
my $o_timeout=      undef; 		# Timeout (Default 5)
# Login options specific
my $o_community = 	undef; 	# community
my $o_version2	=   undef;	#use snmp v2c

# Operational parameters
my $o_bias =        undef; # Transmitter laser bias current
my $o_temp =        undef; # Module temperature
my $o_volt =        undef; # Module voltage
my $o_laser =       undef; # Transmitter laser output power/Receiver laser power

# functions

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | [-p <port>] -n <name in desc_oid> [-t <timeout>] [-BTLV]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nSNMP Network Interface SFP Monitor for Nagios/Icinga ",$Version,"\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information (including interface list on the system)
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY STRING
   community string for the host's SNMP agent (implies v1 protocol)
-2, --v2c
   -2 : use snmp v2c
-P, --port=PORT
   SNMP port (Default 161)
-n, --name=NAME
   Name in description OID (xe-0/0/0, xe-0/0/1...).
-t, --timeout=INTEGER
    timeout for SNMP in seconds (Default: 5)
-B, --bias
    Transmitter laser bias current
-L, --laser
    Receiver laser power/Transmitter laser output power
-T, --temperature
    Module temperature
-V, --voltage
    Module voltage
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'	    => \$o_verb,		'verbose'	    => \$o_verb,
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'	    => \$o_port,
        'n:s'   => \$o_descr,        'name:s'       => \$o_descr,
        'C:s'   => \$o_community,	'community:s'   => \$o_community,
        '2'	    => \$o_version2,	'v2c'		    => \$o_version2,
        't:i'   => \$o_timeout,    	'timeout:i'	    => \$o_timeout,
        'B'	    => \$o_bias,		'bias'	        => \$o_bias,
        'T'	    => \$o_temp,		'temperature'	=> \$o_temp,
        'V'	    => \$o_volt,		'voltage'	    => \$o_temp,
        'L'	    => \$o_laser,		'laser'	        => \$o_laser
    );
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if ( ! defined($o_descr) ||  ! defined($o_host) ) { # check host and filter
        print_usage(); exit $ERRORS{"UNKNOWN"}
    }
    # check snmp information
    if (!defined($o_community)) {
        print "Put snmp info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}
    }
    if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) {
      print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}
    }
    if (!defined($o_timeout)) {$o_timeout=5;}
}

########## MAIN #######

check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT + 5");
  alarm($TIMEOUT+5);
} else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session,$error);
  if (defined ($o_version2)) {
    # SNMPv2c Login
    verb("SNMP v2c login");
    ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
        -version   => 2,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
    );
  } else {
    # SNMPV1 login
    verb("SNMP v1 login");
    ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
    );
  }
if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"UNKNOWN"};
}

# Get desctiption table
my $resultat = $session->get_table(
    Baseoid => $descr_table
);

if (!defined($resultat)) {
    printf("ERROR: Description table : %s.\n", $session->error);
    $session->close;
    exit $ERRORS{"UNKNOWN"};
}
my @tindex = undef;
my @oids = undef;
my @descr = undef;
my $num_int = 0;
my $int_index = undef;

verb("Filter : $o_descr");
foreach my $key ( keys %$resultat) {
   verb("OID : $key, Desc : $$resultat{$key}");
   my $test = $$resultat{$key} eq $o_descr;
  if ($test) {
     # get the index number of the interface
     my @oid_list = split (/\./,$key);
     $tindex[$num_int] = pop (@oid_list);
     # get the full description
     $descr[$num_int]=$$resultat{$key};
     # Get rid of special caracters (specially for Windows)
     $descr[$num_int] =~ s/[[:cntrl:]]//g;
     # put the admin or oper oid in an array
     $oids[$num_int]= $admin_table . $tindex[$num_int];
     verb("Name : $descr[$num_int], Index : $tindex[$num_int]");
     $num_int++;
  }
}

# No interface found -> error
if ( $num_int == 0 ) {
  print "ERROR : Unknown interface $o_descr\n";
  exit $ERRORS{"UNKNOWN"};
} else {
    $int_index = $tindex[0];
}

my $result=undef;

my @oids = undef; # Reinitialize oids

if (defined($o_bias)) {
    $oids[0]= $value_bias_table.$int_index;
    $oids[1]= $low_bias_warn_table.$int_index;
    $oids[2]= $high_bias_warn_table.$int_index;
    $oids[3]= $low_bias_alarm_table.$int_index;
    $oids[4]= $high_bias_alarm_table.$int_index;
} elsif (defined($o_temp)) {
    $oids[0]= $value_temp_table.$int_index;
    $oids[1]= $low_temp_warn_table.$int_index;
    $oids[2]= $high_temp_warn_table.$int_index;
    $oids[3]= $low_temp_alarm_table.$int_index;
    $oids[4]= $high_temp_alarm_table.$int_index;
} elsif (defined($o_volt)) {
    $oids[0]= $value_volt_table.$int_index;
    $oids[1]= $low_volt_warn_table.$int_index;
    $oids[2]= $high_volt_warn_table.$int_index;
    $oids[3]= $low_volt_alarm_table.$int_index;
    $oids[4]= $high_volt_alarm_table.$int_index;
} elsif (defined($o_laser)) {
    $oids[0]= $value_rx_table.$int_index;
    $oids[1]= $low_rx_warn_table.$int_index;
    $oids[2]= $high_rx_warn_table.$int_index;
    $oids[3]= $low_rx_alarm_table.$int_index;
    $oids[4]= $high_rx_alarm_table.$int_index;
    $oids[5]= $value_tx_table.$int_index;
    $oids[6]= $low_tx_warn_table.$int_index;
    $oids[7]= $high_tx_warn_table.$int_index;
    $oids[8]= $low_tx_alarm_table.$int_index;
    $oids[9]= $high_tx_alarm_table.$int_index;
}

# Get the requested oid values
$result = $session->get_request(
   Varbindlist => \@oids
);

if (!defined($result)) { printf("ERROR: table : %s.\n", $session->error); $session->close;
   exit $ERRORS{"UNKNOWN"};
}

$session->close;

# Only a few ms left...
alarm(0);

if (defined($o_bias)) {
  if ($$result{$value_bias_table.$int_index} <= $$result{$low_bias_alarm_table.$int_index} || $$result{$value_bias_table.$int_index} >= $$result{$high_bias_alarm_table.$int_index}) {
    print $o_descr,": ", $$result{$value_bias_table.$int_index}/1000, " mA: CRITICAL";
    print "\n";
    exit $ERRORS{"CRITICAL"};
  } elsif ($$result{$value_bias_table.$int_index} <= $$result{$low_bias_warn_table.$int_index} || $$result{$value_bias_table.$int_index} >= $$result{$high_bias_warn_table.$int_index}) {
    print $o_descr,": ", $$result{$value_bias_table.$int_index}/1000, " mA: WARNING";
    print "\n";
    exit $ERRORS{"WARNING"};
  } else  {
    print $o_descr,": ", $$result{$value_bias_table.$int_index}/1000, " mA: OK";
    print "\n";
    exit $ERRORS{"OK"};
  }
} elsif (defined($o_temp)) {
  if ($$result{$value_temp_table.$int_index} <= $$result{$low_temp_alarm_table.$int_index} || $$result{$value_temp_table.$int_index} >= $$result{$high_temp_alarm_table.$int_index}) {
    print $o_descr,": ", $$result{$value_temp_table.$int_index}, " degrees C: CRITICAL";
    print "\n";
    exit $ERRORS{"CRITICAL"};
  } elsif ($$result{$value_temp_table.$int_index} <= $$result{$low_temp_warn_table.$int_index} || $$result{$value_temp_table.$int_index} >= $$result{$high_temp_warn_table.$int_index}) {
    print $o_descr,": ", $$result{$value_temp_table.$int_index}, " degrees C: WARNING";
    print "\n";
    exit $ERRORS{"WARNING"};
  } else  {
    print $o_descr,": ", $$result{$value_temp_table.$int_index}, " degrees C: OK";
    print "\n";
    exit $ERRORS{"OK"};
  }
} elsif (defined($o_volt)) {
  if ($$result{$value_volt_table.$int_index} <= $$result{$low_volt_alarm_table.$int_index} || $$result{$value_volt_table.$int_index} >= $$result{$high_volt_alarm_table.$int_index}) {
    print $o_descr,": ", $$result{$value_volt_table.$int_index}/1000, " V: CRITICAL";
    print "\n";
    exit $ERRORS{"CRITICAL"};
  } elsif ($$result{$value_volt_table.$int_index} <= $$result{$low_volt_warn_table.$int_index} || $$result{$value_volt_table.$int_index} >= $$result{$high_volt_warn_table.$int_index}) {
    print $o_descr,": ", $$result{$value_volt_table.$int_index}/1000, " V: WARNING";
    print "\n";
    exit $ERRORS{"WARNING"};
  } else  {
    print $o_descr,": ", $$result{$value_volt_table.$int_index}/1000, " V: OK";
    print "\n";
    exit $ERRORS{"OK"};
  }
} elsif (defined($o_laser)) {
  if ($$result{$value_rx_table.$int_index} <= $$result{$low_rx_alarm_table.$int_index} || $$result{$value_rx_table.$int_index} >= $$result{$high_rx_alarm_table.$int_index} || $$result{$value_tx_table.$int_index} <= $$result{$low_tx_alarm_table.$int_index} || $$result{$value_tx_table.$int_index} >= $$result{$high_tx_alarm_table.$int_index}) {
    print $o_descr,": RX: ", $$result{$value_rx_table.$int_index}/100, " dBm TX: ", $$result{$value_tx_table.$int_index}/100, " dBm: CRITICAL";
    print "\n";
    exit $ERRORS{"CRITICAL"};
  } elsif ($$result{$value_rx_table.$int_index} <= $$result{$low_rx_warn_table.$int_index} || $$result{$value_rx_table.$int_index} >= $$result{$high_rx_warn_table.$int_index} || $$result{$value_tx_table.$int_index} <= $$result{$low_tx_warn_table.$int_index} || $$result{$value_tx_table.$int_index} >= $$result{$high_tx_warn_table.$int_index}) {
    print $o_descr,": RX: ", $$result{$value_rx_table.$int_index}/100, " dBm TX: ", $$result{$value_tx_table.$int_index}/100, " dBm: WARNING";
    print "\n";
    exit $ERRORS{"WARNING"};
  } else  {
    print $o_descr,": RX: ", $$result{$value_rx_table.$int_index}/100, " dBm TX: ", $$result{$value_tx_table.$int_index}/100, " dBm: OK";
    print "\n";
    exit $ERRORS{"OK"};
  }
}
