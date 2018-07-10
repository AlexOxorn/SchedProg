#!/usr/bin/perl
use strict;
use warnings;

package Excel;
use FindBin;
use lib "$FindBin::Bin/..";

use Excel::Writer::XLSX;
use Schedule::Schedule;

=head1 NAME

Excel - export Schedule to Excel format. 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    my $excel = Export::Excel->new();
    $excel->export();


=head1 DESCRIPTION



=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
my $HeightOfTimeRows = 6;
my $TitleBorderWidth = 6;
my $TitleFontSize = 16;
my $ScheduleFontSize = 10;
my $SpaceBelowTitle = 20;
my $BlockBorderWidth = 1;
my $BlockColor = 'green';

# =================================================================
# new
# =================================================================

=head2 new ()

creates a Excel export object

B<Parameters>

TODO
-mw => MainWindow to create new Views from

-dirtyFlag => Flag to know when the GuiSchedule has changed since last save

-schedule => where course-sections/teachers/labs/streams are defined 

B<Returns>

GuiSchedule object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    ##??? confess "Bad inputs" if @_%2;

    my %inputs = @_; 
    my $output_file = $inputs{-output_file} || undef;
    
    my $self = { };
    bless $self, $class;
    $self->output_file($output_file);

    return $self;
}

# =================================================================
# output_file
# =================================================================

=head2 output_file ( [outputFileName] )

Gets and sets the output file name.

=cut

sub output_file {
    my $self = shift;
    $self->{-output_file} = shift if @_;
    return $self->{-output_file}
}

# =================================================================
# add
# =================================================================

=head2 add ( row, title, blocks )

Gets and sets the output file name.

=cut

sub add {
    my $self = shift;
    my $row = shift;
    my $title = shift;
    my $blocks = shift;
    $self->{data}->[$row]->{$title} = $blocks;
}

# =================================================================
# export
# =================================================================

=head2 export ( )

Export to file.

=cut

sub export {
    my $self = shift;

    my $workbook = Excel::Writer::XLSX->new($self->output_file);
    my $worksheet = $workbook->add_worksheet();

    ### formats

    my %centering = ( valign => 'vcenter'
                    , align  => 'center'
                    );

    my %format;
    
    $format{centered} = $workbook->add_format(%centering);
    $format{centered}->set_size($ScheduleFontSize);

    $format{title} = $workbook->add_format(%centering);
    $format{title}->set_border($TitleBorderWidth);
    $format{title}->set_size($TitleFontSize);
    
    $format{boldCentered} = $workbook->add_format(%centering);
    $format{boldCentered}->set_bold();
    $format{boldCentered}->set_size($ScheduleFontSize);
    
    $format{block} = $workbook->add_format(%centering);
    $format{block}->set_size($ScheduleFontSize);
    $format{block}->set_border($BlockBorderWidth);
    $format{block}->set_bg_color($BlockColor);

    ###
    
    my $x = 0;
    my $y = 0;

    foreach my $row (@{$self->{'data'}}) {

        foreach my $title (keys %{$row}) {
            
            _add_schedule($worksheet, $x, $y, $title, $row->{$title}, \%format);

            # position next schedule after the current one
            $x += 6;
        }
        
        #reset for next row
        $x = 0;
        $y += 62;
    }

    $workbook->close();
}
    


sub _add_schedule($$$$$$) {
    my $worksheet = shift;
    my $x = shift;
    my $y = shift;
    my $title = shift;
    my $blocks = shift;
    my $formats = shift;
    
    my @blocks = @{$blocks};
    my %format = %{$formats};
                     
    # make schedule title
    $worksheet->merge_range($y, $x, $y + 2, $x + 5,  $title, $format{title});
    $y += 3;
    
    # extra space below title
    $worksheet->set_row($y, $SpaceBelowTitle);   
    $y++;
    
    # week days
    my $i=1;
    foreach my $day ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday') {
        $worksheet->write($y, $x + $i, $day, $format{boldCentered});
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
            my $slotStart = $i / 2 + 8.5; # convert from index to time_number
            my $noBlock = 1;
            foreach my $block (@blocks) {
                if($block->day_number == $j
                   && $block->start_number < $slotStart
                   && ($block->start_number + $block->duration) > $slotStart) {
                    $noBlock = 0;
                    last;
                }
            }
            if($noBlock) {
                $worksheet->merge_range($y + $i * 3, $x + $j, $y + ($i + 1) * 3 - 1, $x + $j, "", $format{centered});
            }
        }
    }
    
    # add time indicators lined up to :30 minute slots
    my $j = 0;
    foreach my $time ("8:30", "9:00","9:30", "10:00","10:30", "11:00","11:30", "12:00","12:30", "13:00","13:30", "14:00","14:30", "15:00","15:30", "16:00","16:30", "17:00") {
        $worksheet->merge_range($y + $j * 3 + 2, $x, $y + $j * 3 + 3 , $x, $time, $format{centered});
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
                                $label, $format{block});
    }
}
