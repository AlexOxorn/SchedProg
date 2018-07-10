#!/usr/bin/perl
use strict;

use FindBin;
use lib "$FindBin::Bin/..";

use Text::CSV;
use Schedule::Schedule;

## debug
use Data::Dumper;


##### main

my $scheduleFileName = shift;
my $outputFileName = shift;

# get schedule for the specified teacher
my $schedule = Schedule->read_YAML($scheduleFileName);

my @flatBlocks;

my %dayNames = ( 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday' );

foreach my $course ( sort { $a->number cmp $b->number } $schedule->courses->list ) {
    foreach my $section ( $course->sections ) {
        foreach my $block ( $section->blocks ) {

            my $start = $block->start_number * 100;
            my $end   = ($block->start_number + $block->duration) * 100;

            # split rooms into "first" and a comma-seperated "rest"
            my @rooms = @{$block->labs};
            my $firstRoom = $rooms[0];
            shift(@rooms);
            my $remainingRooms = join(",", @rooms);
                
            foreach my $teacher ( $block->teachers ) {
                my $teacherName = $teacher->lastname . ", " . $teacher->firstname;

                push(@flatBlocks, ["420"
                                   , $course->name
                                   , $course->number
                                   , $section->number
                                   , 90
                                   , $start
                                   , $end
                                   , $dayNames{$block->day_number}
                                   , "C+-Lecture & Lab combined"
                                   , 30
                                   , $teacherName
                                   , $firstRoom
                                   , $remainingRooms
                                   , ""
                                   , ""
                                   , ""
                                  ]
                    );
 
             
            }
        }
    }
}

                    
open my $fh, ">", $outputFileName or die $!;

my $csv = Text::CSV->new();

foreach my $flatBlock (@flatBlocks) {
    $csv->print($fh, $flatBlock);
    print $fh "\n";
}

close $fh or die $!;

