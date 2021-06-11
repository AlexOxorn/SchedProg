#!/usr/bin/perl
use warnings;
use strict;
use FindBin;

package Tk::FindImages;

use File::Find;
use Cwd;
our $image_dir;
our $logo_file;

sub get_image_dir {
    
    return $image_dir if $image_dir;

    if ($Scheduler::BinDir) {
        return "$Scheduler::BinDir/Tk/Images";
    }
    if ($Allocation::BinDir) {
        return "$Allocation::BinDir/Tk/Images";
    }
	#return "$Scheduler::BinDir/Tk/Images";
	
    ######## THIS CODE IS BAD, AND TAKES A LOT OF TIME
    ######## WAS ORIGINALLY USED IF TRYING TO MAKE A 'PAR' PACKAGE
    ######## WHICH MOVES THE FILES AROUND.
    my $pwd = cwd;

    # search for images in default directory, depending on OS
    eval {
        find( \&wanted, "$FindBin::Bin/.." );
        if ( $^O =~ /darwin/i ) {    # Mac OS linux
            find( \&wanted, $ENV{"HOME"} );
        }
        elsif ( $^O =~ /win/i ) {
            find( \&wanted, $ENV{"TEMP"} );
        }
        else {
            find( \&wanted, $ENV{"HOME"} );
        }

        # if default image not found,
        # search directories until found (shouldn't happen)
        if ( !defined $image_dir ) {
            find( \&wanted, $pwd );
            while ( !defined $image_dir ) {
                find( \&wanted, "../" );
            }
        }
    };
        
    if ( $@ !~ 'found it' ) {
        chdir($pwd);
        die $@;
    }
    
    chdir($pwd);
    return $image_dir;
}

sub get_allocation_logo {
	return "$Allocation::BinDir/AllocationLogo.gif";    
}

sub get_logo {
	
	return "$Scheduler::BinDir/ScheduleLogo.gif";
    return $logo_file if $logo_file;

    my $pwd = cwd;

    # search for images in default directory, depending on OS
    eval {
        find( \&wantedLogo, "$FindBin::Bin/.." );
        if ( $^O =~ /darwin/i ) {    # Mac OS linux
            find( \&wantedLogo, $ENV{"HOME"} );
        }
        elsif ( $^O =~ /win/i ) {
            find( \&wantedLogo, $ENV{"TEMP"} );
        }
        else {
            find( \&wantedLogo, $ENV{"HOME"} );
        }

        # if default image not found,
        # search directories until found (shouldn't happen)
        if ( !defined $image_dir ) {
            find( \&wantedLogo, $pwd );
            while ( !defined $image_dir ) {
                find( \&wantedLogo, "../" );
            }
        }
    };
        
    if ( $@ !~ 'found it' ) {
        chdir($pwd);
        die $@;
    }
    
    chdir($pwd);
    return $logo_file;
}

sub wanted {
    if ( $_ eq "Tk" && -d $_ . "/Images" ) {
        $image_dir = $File::Find::dir . "/" . $_ . "//Images";
        die "found it";
    }
}

sub wantedLogo {
    if($_ eq "ScheduleLogo.gif") {
        $logo_file = $File::Find::dir . "/ScheduleLogo.gif";    
        die "found it";
    }
}

1;

