#!/usr/bin/perl
use strict;

use FindBin;
use lib "$FindBin::Bin/..";

use Excel::Writer::XLSX;
use Schedule::Schedule;

## debug
use Data::Dumper;

#### Globals used for output configuration
my $HeightOfTimeRows = 6;
my $TitleBorderWidth = 6;
my $TitleFontSize = 16;
my $ScheduleFontSize = 10;
my $SpaceBelowTitle = 20;
my $BlockBorderWidth = 1;
my $BlockColor = 'green';

##### main

my $scheduleFileName = shift;
my $outputFileName = shift;

# get schedule for the specified teacher
my $schedule = Schedule->read_YAML($scheduleFileName);

my @teachers = sort { $a->lastname cmp $b->lastname} $schedule->teachers->list;
my @rooms    = sort { $a->number cmp $b->number} $schedule->labs->list;

my $workbook = Excel::Writer::XLSX->new($outputFileName);
my $worksheet = $workbook->add_worksheet();

### formats
my %centering = ( valign => 'vcenter'
                , align  => 'center'
                );

my $centeredFmt = $workbook->add_format(%centering);
$centeredFmt->set_size($ScheduleFontSize);

my $titleFmt = $workbook->add_format(%centering);
$titleFmt->set_border($TitleBorderWidth);
$titleFmt->set_size($TitleFontSize);

my $boldCenteredFmt = $workbook->add_format(%centering);
$boldCenteredFmt->set_bold();
$boldCenteredFmt->set_size($ScheduleFontSize);

my $blockFmt = $workbook->add_format(%centering);
$blockFmt->set_size($ScheduleFontSize);
$blockFmt->set_border($BlockBorderWidth);
$blockFmt->set_bg_color($BlockColor);

sub addSchedule($$$$) {
    my $x = shift;
    my $y = shift;
    my $title = shift;
    my $blocks = shift;
    my @blocks = @{$blocks};
                     
    # make schedule title
    $worksheet->merge_range($y, $x, $y + 2, $x + 5,  $title, $titleFmt);
    $y += 3;
    
    # extra space below title
    $worksheet->set_row($y, $SpaceBelowTitle);   
    $y++;
    
    # week days
    my $i=1;
    foreach my $day ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday') {
        $worksheet->write($y, $x + $i, $day, $boldCenteredFmt);
        $i++;
    }
    $y++;

    # adjust height of all the time rows (each :30 has 3 rows)
    for(my $i=0; $i < 19 * 3; $i++) {
        $worksheet->set_row($y + $i, $HeightOfTimeRows);
    }
    
    # merge all :30 minute slots
    for(my $j = 1; $j < 6; $j++) {
        for(my $i = 0; $i < 19; $i++) {
            $worksheet->merge_range($y + $i * 3, $x + $j, $y + ($i + 1) * 3 - 1, $x + $j, "", $centeredFmt);
        }
    }
    
    # add time indicators lined up to :30 minute slots
    my $j = 0;
    foreach my $time ("8:30", "9:00","9:30", "10:00","10:30", "11:00","11:30", "12:00","12:30", "13:00","13:30", "14:00","14:30", "15:00","15:30", "16:00","16:30", "17:00") {
        $worksheet->merge_range($y + $j * 3 + 2, $x, $y + $j * 3 + 3 , $x, $time, $centeredFmt);
        $j++;
    }
    
    # add blocks
    foreach my $block (@blocks) {
        # get needed block information
        my $name     = $block->section->course->number . '/' . $block->section->number;
        my $teachers = sprintf( join( "\n", map { substr($_->firstname, 0, 1) . substr($_->lastname, 0, 1) } $block->teachers ) ) || "";
        my $rooms    = sprintf( join( ",", $block->labs ) ) || "";
        my $label    = sprintf( join("\n", ($name, $teachers, $rooms) ));
        
        $worksheet->merge_range($y + ($block->start_number - 8) * 2 * 3,
                                $x + $block->day_number,
                                $y + ($block->start_number - 8) * 2 * 3 + $block->duration * 2 * 3 - 1,
                                $x + $block->day_number,
                                $label, $blockFmt);
    }
}

my $x = 0;
my $y = 0;
foreach my $teacher (@teachers) {
    my @teacherBlocks = $schedule->blocks_for_teacher($teacher);
    my $title = $teacher->firstname . ' ' . $teacher->lastname;
    addSchedule($x, $y, $title, \@teacherBlocks);
    $x += 6;
}

$x = 0;
$y += 62;
foreach my $room (@rooms) {
    my @roomBlocks = $schedule->blocks_in_lab($room);
    my $title = $room->number;
    addSchedule($x, $y, $title, \@roomBlocks);
    $x += 6;
}
    
