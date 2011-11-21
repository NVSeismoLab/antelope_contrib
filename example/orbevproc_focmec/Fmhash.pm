#
#   Copyright (c) 2011 Lindquist Consulting, Inc.
#   All rights reserved. 
#                                                                     
#   Written by Dr. Kent Lindquist, Lindquist Consulting, Inc. 
#
#   This software is licensed under the New BSD license: 
#
#   Redistribution and use in source and binary forms,
#   with or without modification, are permitted provided
#   that the following conditions are met:
#   
#   * Redistributions of source code must retain the above
#   copyright notice, this list of conditions and the
#   following disclaimer.
#   
#   * Redistributions in binary form must reproduce the
#   above copyright notice, this list of conditions and
#   the following disclaimer in the documentation and/or
#   other materials provided with the distribution.
#   
#   * Neither the name of Lindquist Consulting, Inc. nor
#   the names of its contributors may be used to endorse
#   or promote products derived from this software without
#   specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
#   CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
#   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
#   THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY
#   DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
#   IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
#   USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#

package Fmhash;

use lib "$ENV{ANTELOPE}/data/evproc";

our @ISA = ( "Focmec" );

use evproc;

use strict;
use warnings;
use POSIX;
use Math::Trig;

use lib "$ENV{ANTELOPE}/data/perl";

use Datascope;

sub new {
	return Focmec::new @_;
}

sub setup_parameters {
	my $obj = shift;

	my @expected = qw( hash_executable
			   fplane_algorithm
			   fplane_auth
			   tempdir
			   maximum_wait_time 
			   min_num_polarities
			   max_azim_gap_deg
			   max_takeoff_angle_deg
			   grid_angle_deg
			   num_trials
			   num_maxout
			   badpick_fraction
			   distance_cutoff_km
			   probability_angle_deg
			   probability_thresh
			   );

	foreach my $param ( @expected ) {

		if( ! defined $obj->{params}{$param} ) {
		
			addlog( $obj, 0, "Parameter '$param' not defined in parameter file" );
			return "skip";
		}
	}
	
	my $hash_executable = datafile( "PATH", $obj->{params}{hash_executable} );

	if( ! defined( $hash_executable ) ) {

		addlog( $obj, 0, "hash_executable '$obj->{params}{hash_executable}' not found on path" );
		return "skip";

	} elsif( ! -x "$hash_executable" ) {

		addlog( $obj, 0, "hash_executable '$obj->{params}{hash_executable}' not executable" );
		return "skip";

	} else {

		$obj->{params}{hash_executable} = abspath( $hash_executable );
	}

	return "ok";
}

sub getwftimes {
	my $self = shift;

	my $ret = setup_parameters( $self );

	if( $ret ne "ok" ) {

		return makereturn( $self, $ret );
	}

	$self->put( "stations", {} );

	$self->put( "expire_time", now() + $self->{params}{maximum_wait_time} );

	return makereturn( $self, "ok", 
			   "stations" => $self->get( "stations" ), 
			   "expire_time" => $self->get( "expire_time" ) ); 
}

sub process_channel {
	my $self = shift;
	my $ret = $self->SUPER::process_channel( @_ );

	return $ret;
}

sub process_station {
	my $self = shift;
	my $ret = $self->SUPER::process_station( @_ );

	return $ret;
}

sub prepare_hash_input {
	my $self = shift;
	my $disp = "ok";

	$self->put( "hash_inputfile_phase",     "hash_in_$self->{event_id}.phase" );
	$self->put( "hash_inputfile_control",  	"hash_in_$self->{event_id}.inp" );
	$self->put( "hash_inputfile_reversals",	"hash_in_$self->{event_id}.reverse" );
	$self->put( "hash_outputfile_stdout", 	"hash_out_$self->{event_id}.stdout" );
	$self->put( "hash_outputfile_fmout", 	"hash_out_$self->{event_id}.fmout" );
	$self->put( "hash_outputfile_plout", 	"hash_out_$self->{event_id}.plout" );

	$self->put( "hash_phase_block", "" );
	$self->put( "hash_control_block", "" );
	$self->put( "hash_reversals_block", "" );

	# Control File

	$self->{hash_control_block} .= $self->get( "hash_inputfile_reversals" )->[0] . "\n";
	$self->{hash_control_block} .= $self->get( "hash_inputfile_phase" )->[0] . "\n";
	$self->{hash_control_block} .= $self->get( "hash_outputfile_fmout" )->[0] . "\n";
	$self->{hash_control_block} .= $self->get( "hash_outputfile_plout" )->[0] . "\n";
	$self->{hash_control_block} .= sprintf( "%d", $self->{params}{"min_num_polarities"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%f", $self->{params}{"max_azim_gap_deg"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%f", $self->{params}{"max_takeoff_angle_deg"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%f", $self->{params}{"grid_angle_deg"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%d", $self->{params}{"num_trials"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%d", $self->{params}{"num_maxout"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%f", $self->{params}{"badpick_fraction"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%f", $self->{params}{"distance_cutoff_km"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%f", $self->{params}{"probability_angle_deg"} ) . "\n";
	$self->{hash_control_block} .= sprintf( "%f", $self->{params}{"probability_thresh"} ) . "\n";

	# Phase File

	my( @dbo, @dboe, @dbj );
	my( $origin_time, $lat, $lon, $depth, $ml, $mb, $ms, $orid );
	my( $smajax, $sdepth );
	my( $stime, $ilat, $ns, $mlat, $ilon, $ew, $mlon, $dkm, $mag );
	my( $mag_string, $smajax_string, $sdepth_string );

	@dbo = @{$self->{dbo}};

	if( dbquery( @dbo, dbRECORD_COUNT ) < 1 ) {

		addlog( $self, 0, "Database origin table does not have any rows\n" );
		return "skip";

	} else {

		$dbo[3] = 0;
	}

	( $origin_time, $lat, $lon, $depth, $ml, $mb, $ms, $orid ) =
		dbgetv( @dbo, "time", "lat", "lon", "depth", "ml", "mb", "ms", "orid" );

	@dboe = @{$self->{dboe}};

	if( dbquery( @dboe, dbRECORD_COUNT ) < 1 ) {

		addlog( $self, 0, "Database origerr table does not have any rows\n" );
		return "skip";

	} else {

		$dboe[3] = 0;
	}

	( $smajax, $sdepth ) = dbgetv( @dboe, "smajax", "sdepth" );

	$stime = epoch2str( $origin_time, "%y%m%d%H%M" ) . 
	 	 sprintf( "%02d", epoch2str( $origin_time, "%S" ) ) . 
		 sprintf( "%02d", int( epoch2str( $origin_time, "%s" ) / 10 ) );

	$mlat = 60 * substr( $lat, index( $lat, "." ) );
	$mlat = int( $mlat * 100 );
	$ns = $lat >= 0 ? "N" : "S";
	$ilat = int( abs( $lat ) );

	$mlon = 60 * substr( $lon, index( $lon, "." ) );
	$mlon = int( $mlon * 100 );
	$ew = $lon >= 0 ? "E" : "W";
	$ilon = int( abs( $lon ) );

	$dkm = sprintf( "%05d", $depth * 100 );

	if( $ms != -999.00 ) {

		$mag = $ms;

	} elsif( $mb != -999.00 ) {

		$mag = $mb;

	} elsif( $ml != -999.00 ) {

		$mag = $ml;

	} else {

		$mag = -999.00;
	}

	if( $mag == -999.00 ) {
		
		$mag_string = "  ";

	} else {

		$mag_string = sprintf( "%02d", int( $mag * 10 ) );
	}

	if( $smajax == -1.0 ) {

		$smajax_string = "    ";

	} else {
		
		$smajax_string = sprintf( "%04d", int( $smajax * 100 ) );
	}

	if( $sdepth == -1.0 ) {

		$sdepth_string = "    ";

	} else {
		
		$sdepth_string = sprintf( "%04d", int( $sdepth * 100 ) );
	}

	$self->{hash_phase_block} .= sprintf( "%14s%02d%1s%04d%03d%1s%04d%5s%2s",
				              $stime, $ilat, $ns, $mlat, $ilon, $ew, $mlon, $dkm, $mag_string );

	$self->{hash_phase_block} .= " " x 44;

	$self->{hash_phase_block} .= sprintf( "%4s%4s", $smajax_string, $sdepth_string );

	$self->{hash_phase_block} .= " " x 35;

	$self->{hash_phase_block} .= sprintf( "% 16s", $orid );

	return $disp;

	###############
	# SCAFFOLD: OLD
	###############
	
	# my( $stime, $ilat, $ns, $mlat, $ilon, $ew, $mlon, $dkm, $mag, $nprecs, $rms );
	# my( @dbo, @dboe, @dbj );
	# my( $origin_time, $lat, $lon, $depth, $ml, $mb, $ms );
	# my( $sta, $phase, $fm, $snr, $arrival_time, $deltim, $delta, $esaz, $timeres );
	# my( $sdobs, $angle, $tobs, $imp, $pwt, $ptime );

	# $self->put( "fpfit_inputfile_hyp",     "fpfit_in_$self->{event_id}.hyp" );
	# $self->put( "fpfit_outputfile_out",    "fpfit_out_$self->{event_id}.out" );
	# $self->put( "fpfit_outputfile_sum",    "fpfit_out_$self->{event_id}.sum" );
	# $self->put( "fpfit_outputfile_pol",    "fpfit_out_$self->{event_id}.pol" );
	# $self->put( "fpfit_outputfile_stdout", "fpfit_out_$self->{event_id}.stdout" );

	# $self->put( "fpfit_hyp_block", "" );

	# @dbo = @{$self->{dbo}};

	# if( dbquery( @dbo, dbRECORD_COUNT ) < 1 ) {

	# 	addlog( $self, 0, "Database origin table does not have any rows\n" );
	# 	return "skip";

	# } else {

	# 	$dbo[3] = 0;
	# }

	# ( $origin_time, $lat, $lon, $depth, $ml, $mb, $ms ) =
	# 	dbgetv( @dbo, "time", "lat", "lon", "depth", "ml", "mb", "ms" );

	# @dboe = @{$self->{dboe}};

	# if( dbquery( @dboe, dbRECORD_COUNT ) < 1 ) {

	# 	addlog( $self, 0, "Database origerr table does not have any rows\n" );
	# 	return "skip";

	# } else {

	# 	$dboe[3] = 0;
	# }

	# $sdobs = dbgetv( @dboe, "sdobs" );

	# $stime = epoch2str( $origin_time, "%y%m%d %H%M " ) . 
	 # 	 sprintf( "%05.2f", epoch2str( $origin_time, "%S.%s" ) );

	# $mlat = 60 * substr( $lat, index( $lat, "." ) );
	# $ns = $lat >= 0 ? "n" : "s";
	# $ilat = int( abs( $lat ) );

	# $mlon = 60 * substr( $lon, index( $lon, "." ) );
	# $ew = $lon >= 0 ? "e" : "w";
	# $ilon = int( abs( $lon ) );

	# $dkm = sprintf( "%.2f", $depth );
	# $rms = sprintf( "%.2f", $sdobs );

	# if( $ms != -999.00 ) {

	# 	$mag = $ms;

	# } elsif( $mb != -999.00 ) {

	# 	$mag = $mb;

	# } elsif( $ml != -999.00 ) {

	# 	$mag = $ml;

	# } else {

	# 	$mag = 0.0;
	# }

	# @dbj = dbjoin( @{$self->{dbar}}, @{$self->{dbas}} );

	# @dbj = dbsubset( @dbj, 
# 	  "iphase == 'P' && delta * 111.191 <= $self->{params}{distance_cutoff_km} && strlen(chan) <= 4" );

	# $nprecs = dbquery( @dbj, "dbRECORD_COUNT" );

	# $self->{fpfit_hyp_block} .= "  DATE    ORIGIN   LATITUDE LONGITUDE  DEPTH    MAG NO           RMS\n";
	# $self->{fpfit_hyp_block} .= sprintf( " %17s%3d%1s%5.2f%4d%1s%5.2f%7.2f  %5.2f%3d         %5.2f\n",
	# 			    $stime, $ilat, $ns, $mlat, $ilon, $ew, $mlon, $dkm, $mag, $nprecs, $rms );

	# $self->{fpfit_hyp_block} .= "\n  STN  DIST  AZ TOA PRMK HRMN  PSEC TPOBS              PRES  PWT\n";

	# for( $dbj[3] = 0; $dbj[3] < $nprecs; $dbj[3]++ ) {

	# 	( $sta, $phase, $fm, $snr, $arrival_time, $deltim ) = 
	# 		dbgetv( @dbj, "sta", "phase", "fm", "snr", "time", "deltim" );

	# 	( $delta, $esaz, $timeres ) = dbgetv( @dbj, "delta", "esaz", "timeres" );

	# 	$delta *= 111.191;

	# 	my( $angle ) = atan2( $delta, $depth ) * 180 / pi;

	# 	my( $tobs ) = $arrival_time - $origin_time;

	# 	if( substr( $fm, 0, 1 ) eq "c" ) {

	# 		$fm = "U";

	# 	} elsif( substr( $fm, 0, 1 ) eq "d" ) {
			
	# 		$fm = "D";

	# 	} else {

	# 		$fm = " ";
	# 	}

	# 	if( $deltim < 0.05 ) {

	# 		$pwt = "0";
	# 		$imp = "I";

	# 	} elsif( $deltim < 0.1 ) {

	# 		$pwt = "1";
	# 		$imp = " ";

	# 	} elsif( $deltim < 0.2 ) {

	# 		$pwt = "2";
	# 		$imp = " ";

	# 	} else {

	# 		$pwt = "4";
	# 		$imp = " ";
	# 	}

	# 	$ptime = epoch2str( $arrival_time, "%H%M " ) .
	# 		sprintf( "%05.2f", epoch2str( $arrival_time, "%S.%s" ) );

	# 	$self->{fpfit_hyp_block} .= 
	# 		sprintf( " %4s%6.1f %3d %3d %1s%1s%1s%1s %10s%6.2f             %5.2f  1.00\n",
	# 		     $sta, $delta, $esaz, $angle, $imp, $phase, $fm, $pwt, $ptime, $tobs, $deltim );
	# }

	# return $disp;
}

sub invoke_hash {
	my $self = shift;

	my( $startdir, $infile );

	$startdir = POSIX::getcwd();

	POSIX::chdir( $self->{params}{tempdir} );

	( $infile ) = $self->get( "hash_inputfile_phase" );
	print "SCAFFOLD phase file is '$infile'\n";

	open( I, "> $infile" );

	print I $self->get( "hash_phase_block" );
	print "SCAFFOLD phase block is: " . ( $self->get( "hash_phase_block" ) ) . "\n";

	close( I );

	( $infile ) = $self->get( "hash_inputfile_control" );
	print "SCAFFOLD control file is '$infile'\n";

	open( I, "> $infile" );

	print I $self->get( "hash_control_block" );
	print "SCAFFOLD control block is: " . ( $self->get( "hash_control_block" ) ) . "\n";

	close( I );

	( $infile ) = $self->get( "hash_inputfile_reversals" );

	open( I, "> $infile" );

	print I $self->get( "hash_reversals_block" );

	close( I );

	return;

	###############
	# SCAFFOLD: OLD
	###############

#	my $startdir = POSIX::getcwd();

#	POSIX::chdir( $self->{params}{tempdir} );

#	my( $infile ) = $self->get( "hash_inputfile_phase" );

#	open( I, "> $infile" );

#	print I $self->get( "hash_phase_block" );

#	close( I );

#	my( $stdoutfile, $hypfile, $outfile, $sumfile, $polfile ) = $self->get( "fpfit_outputfile_stdout",
#										"fpfit_inputfile_hyp",
#										"fpfit_outputfile_out",
#										"fpfit_outputfile_sum",
#										"fpfit_outputfile_pol" );

#	open( F, "| $self->{params}{hash_executable} > $stdoutfile" );

	# Use default title, hypo filename plus date, i.e. choice "1"
#	print F "ttl 1 none\n";

#	print F "hyp $hypfile\n";
#	print F "out $outfile\n";
#	print F "sum $sumfile\n";
#	print F "pol $polfile\n";
#	print F "fit none\n";

	# Set to "hypo71 print listing" i.e. input format "1"
# 	print F "for 1\n";	

# 	print F "amp $self->{params}{use_radiation_pattern_weighting}\n";
# 	print F "fin $self->{params}{perform_fine_search}\n";

	#Output only the best solution
# 	print F "bst 1\n";

	#Output single (not composite) solutions
# 	print F "cmp 0\n";

# 	print F "mag $self->{params}{min_magnitude}\n";
# 	print F "obs $self->{params}{min_observations}\n";
# 	print F "dis $self->{params}{distance_cutoff_km}\n";

# 	print F "res $self->{params}{presidual_cutoff_sec}\n";

# 	print F "ain $self->{params}{incidence_angle_min_deg} " .
# 		    "$self->{params}{incidence_angle_max_deg}\n";

# 	print F "dir $self->{params}{strike_search_min_deg} " .
# 		    "$self->{params}{strike_search_max_deg} " .
# 		    "$self->{params}{strike_search_coarse_incr} " .
# 		    "$self->{params}{strike_search_fine_incr}\n";

# 	print F "dip $self->{params}{dip_search_min_deg} " .
# 		    "$self->{params}{dip_search_max_deg} " .
# 		    "$self->{params}{dip_search_coarse_incr} " .
# 		    "$self->{params}{dip_search_fine_incr}\n";

# 	print F "rak $self->{params}{rake_search_min_deg} " .
# 		    "$self->{params}{rake_search_max_deg} " .
# 		    "$self->{params}{rake_search_coarse_incr} " .
# 		    "$self->{params}{rake_search_fine_incr}\n";

	# print F "hdr $self->{params}{pweight_percentages}\n";

	# print F "fps\n";
	# print F "sto\n";
	# close( F );

	# POSIX::chdir( $startdir );

	# return;
}

sub harvest_hash {
	my $self = shift;

 	return "ok";

	###############
	# SCAFFOLD: OLD 
	###############

	# my( $sumfile ) = $self->get( "fpfit_outputfile_sum" );

	# my( $resultsfile ) = concatpaths( $self->{params}{tempdir}, $sumfile );

	# if( ! -f $resultsfile ) {

	# 	addlog( $self, 0, "Results file '$resultsfile' from fpfit does not exist\n" );

	# 	return "skip";
	# }

	#  open( O, $resultsfile );

	# my $summary_line = <O>;

	# close( O );

	# my( $strike ) = substr( $summary_line, 83, 3 );
	# my( $dip ) = substr( $summary_line, 87, 2 );
	# my( $rake ) = substr( $summary_line, 90, 3 );
	# my( $fj ) = substr( $summary_line, 94, 5 );

	# my( $strike_aux, $dip_aux, $rake_aux ) = Focmec::aux_plane( $strike, $dip, $rake );

	# my( $taxazm, $taxplg, $paxazm, $paxplg ) = Focmec::tp_axes( $strike, $dip, $rake, $strike_aux, $dip_aux, $rake_aux );

	# my( $auth );

	# if( $self->{params}{fplane_auth} ne "" ) {
		
	# 	$auth = $self->{params}{fplane_auth};

	# } else {

	# 	$auth = "evproc:$ENV{USER}";
	# }

	# my @dbfplane = dblookup( @{$self->{dbm}}, 0, "fplane", "", "dbSCRATCH" );

	# my $mechid = dbnextid( @{$self->{dbm}}, "mechid" );

	# dbputv( @dbfplane, "orid", $self->{orid},
	# 		   "mechid", $mechid,
	# 	   	   "str1", $strike,
	# 		   "dip1", $dip, 
	# 		   "rake1", $rake, 
	# 	   	   "str2", $strike_aux,
	# 		   "dip2", $dip_aux, 
	# 		   "rake2", $rake_aux, 
	# 		   "taxazm", $taxazm,
	# 		   "paxazm", $paxazm,
	# 		   "taxplg", $taxplg,
	# 		   "paxplg", $paxplg,
	# 		   "auth", $auth,
	# 		   "algorithm", $self->{params}{fplane_algorithm} );

# 	my $rec = dbadd( @dbfplane );

# 	$dbfplane[3] = $rec;
# 	$dbfplane[2] = $rec + 1;
# 
# 	push @{$self->{output}{db}{tables}}, \@dbfplane;

# 	return "ok";
}

sub process_network {
	my $self = shift;
	my $ret = $self->SUPER::process_network( @_ );

	my $disp = prepare_hash_input( $self );

	if( $disp ne "ok" ) {

		addlog( $self, 0, "Failed to prepare hash input file\n" );
		return "skip";
	}

	invoke_hash( $self );

	$disp = harvest_hash( $self );

	if( $disp ne "ok" ) {

		addlog( $self, 0, "Failed to harvest results from hash output file\n" );
		return "skip";
	}

	return makereturn( $self, $disp );
}

1;

