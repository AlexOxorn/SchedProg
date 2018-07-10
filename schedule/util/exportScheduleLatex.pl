#!/usr/bin/perl
use strict;

use FindBin;
use lib "$FindBin::Bin/..";

use Schedule::Schedule;

# Convert day_numbers to day in the LaTeX output
my @dayAsLatexMacro = ("<DAY>", "\\monday", "\\tuesday", "\\wednesday", "\\thursday", "\\friday");

sub blockToLatex($) {
    my $block = shift;

    # get needed block information
	my $courseName    = $block->section->course->name || "<NAME>";
    my $courseCode    = "<CODE>"; #$block->section->course->course_id || "<CODE>";
	my $courseSection = $block->section->number || "<SECTION>";
    my @rooms         = $block->labs;
	my $roomText      = sprintf( join( ",", @rooms ) ) || "";
	my $duration      = $block->duration;
	my $startTime     = $block->start_number;
    my $day           = $dayAsLatexMacro[$block->day_number];

    # generate the TikZ command for a block node. see "template.tex"
    return "\\node[course={$duration}{1}] at ($day,$startTime) {$courseName \\\\ $courseCode Sec $courseSection \\\\ $roomText};"
}

##### main


my $scheduleFileName = shift;
my $teacherFirstName = shift;
my $teacherLastName = shift;

# get schedule for the specified teacher
my $schedule = Schedule->read_YAML($scheduleFileName);
my $teacher = $schedule->teachers->get_by_name($teacherFirstName, $teacherLastName);
my @teacherBlocks = $schedule->blocks_for_teacher($teacher);

# convert blocks to latex
my @teacherBlocksLatex;
foreach my $block (@teacherBlocks) {
    push(@teacherBlocksLatex, blockToLatex($block));
}

open(my $fh, '<', "template.tex") or die "Could not open template file";
while(my $line = <$fh>) {
    chomp $line;

    # replace name with provided teacher name
    if($line =~ /!!!NAME!!!/) {
        $line =~ s/!!!NAME!!!/$teacherFirstName $teacherLastName/;
    }

    # replace schedule. Warning cannot be embedded in a single line.
    if($line =~ /!!!SCHEDULE!!!/) {
        foreach my $latex (@teacherBlocksLatex) {
            print $latex . "\n";
        }
        next;
    }

    print $line . "\n";
}
close($fh)
