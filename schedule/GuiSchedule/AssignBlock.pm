#!/usr/bin/perl
use strict;
use warnings;

package AssignBlock;
use FindBin;
use lib "$FindBin::Bin/..";
use PerlLib::Colours;
use GuiSchedule::ViewBase;
use Carp;

=head1 NAME

AssignBlock - A half hour time block used to select time slots on a view

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    # Use from a View object
    
    use GuiSchedule::AssignBlock;
    my $view = $self;
    
    # Create blocks for each time
    my @all_blocks;
    foreach my $day ( 1 ... 5 ) {
        foreach my $start ( $EarliestTime * 2 ... ( $LatestTime * 2 ) - 1 ) {
            push @all_blocks, AssignBlock->new($view,$day,$start);
        }
    }
    
    # Get block at canvas position x,y (use class method)
    my $block = AssignBlock->find( $x, $y,\@all_blocks);

    # use the AssignBlock object to get info
    my $day = $block->day;
    $block->colour("lime green");
    
    # Get all the blocks for a specific day between start & stop time (inclusive) (use class method)
    my @selected = AssignBlock->get_day_blocks( $day, \@all_blocks);
    
    # Find all blocks that contain a certain x,y range
    my @selected = AssignBlock->in_range($x1,$y1,$x2,$y2, \@day_blocks)
    

=head1 DESCRIPTION

Defines a 1/2 hour block of time within a view.  

You can find this time block by specifying the x/y canvas coordinates, or by the
day, start and end time.

The block can be coloured, or uncoloured.

=cut

# =================================================================
# Global Variables
# =================================================================
my %dayTag = (
	"1" => "monday",
	"2" => "tuesday",
	"3" => "wednesday",
	"4" => "thursday",
	"5" => "friday"
);

=head1 CLASS METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ($view, $day, $start)

creates, draws and returns an AssignBlock

B<Parameters>

$view  View the GuiBlock will be drawn on

$day  day of the week (integer, 1=monday etc)

$start time that this gui block starts (real number)

B<Returns>

AssignBlock object

=cut

sub new {
	my $class = shift;
	my $view  = shift;
	my $day   = shift;
	my $start = shift;
	carp("You need a view!!!") unless $view;

	use Data::Dumper;

	# ---------------------------------------------------------------
	# draw 1/2 the block
	# ---------------------------------------------------------------
	my $cn = $view->canvas;
	my @coords = $view->get_time_coords( $day, $start, 1 / 2 );

	my $r = $cn->createRectangle(
		@coords,
		-outline => 'red',
		-width   => 0,
		-tags    => $dayTag{"$day"},
	);
	$cn->lower($r,'all');

	# ---------------------------------------------------------------
	# create object
	# ---------------------------------------------------------------
	my $self = {};
	bless $self, $class;

	# ---------------------------------------------------------------
	# save object info
	# ---------------------------------------------------------------
	$self->id($r);
	$self->day($day);
	$self->start($start);
	$self->view($view);
	$self->canvas( $view->canvas );

	# just in case, want coords to be from top left -> bottom right
	# or other logic in this class may fail

	my $x1 = $coords[0];
	my $y1 = $coords[1];
	my $x2 = $coords[2];
	my $y2 = $coords[3];

	if ( $x1 > $x2 ) { my $tmp = $x1; $x1 = $x2; $x2 = $x1; }
	if ( $y1 > $y2 ) { my $tmp = $y1; $y1 = $y2; $y2 = $y1; }
	$self->x1($x1);
	$self->y1($y1);
	$self->x2($x2);
	$self->y2($y2);

	return $self;
}

# =================================================================
# find ($x, $y, $blocks)
# =================================================================

=head2 at_canvas_coords ($x, $y, $blocks)

find the first block within blocks that contains the canvas coords $x, $y

B<Parameters>

($x, $y)  canvas coordinates

$blocks array pointer of AssignBlocks

B<Returns>

Assign Block object

=cut

sub find {
	my $class  = shift;
	my $x      = shift;
	my $y      = shift;
	my $blocks = shift;
	return unless $blocks;

	my @found;
	@found = grep { $_->at_canvas_coords( $x, $y ) } @$blocks;

	return $found[0] if @found;
	return;
}

# =================================================================
# in_range ($x1,$y1,$x2,$y2, $blocks)
# =================================================================

=head2 in_range ($x1,$y1,$x2,$y2, $blocks)

return an array of all blocks within a certain rectangular area

B<Parameters>

$x1,$y1,$x2,$y2 rectangle area coordinates

$blocks array pointer of AssignBlocks

B<Returns>

Array of AssignBlock objects

=cut

sub in_range {
	my $class  = shift;
	my $x1     = shift || 1;
	my $y1     = shift || 1;
	my $x2     = shift || 1;
	my $y2     = shift || 1;
	my $blocks = shift;
	die unless $blocks;

	# make sure start in left top towards bottom right
	if ( $x1 > $x2 ) { my $tmp = $x1; $x1 = $x2; $x2 = $tmp; }
	if ( $y1 > $y2 ) { my $tmp = $y1; $y1 = $y2; $y2 = $tmp; }

	return
	  grep { $_->x1 < $x2 && $_->x2 > $x1 && $_->y1 < $y2 && $_->y2 > $y1 }
	  @$blocks;
}

=head1 INSTANCE METHODS

=cut

# =================================================================
# at_canvas_coords ($x, $y)
# =================================================================

=head2 at_canvas_coords ($x, $y)

does this block contain the canvas coords $x, $y

NOTE: will not return true if edge is detected, which is not a bad 
thing because maybe user wanted something else

B<Parameters>

($x, $y) canvas coordinates

B<Returns>

true or false

=cut

sub at_canvas_coords {
	my $self = shift;
	my $x    = shift;
	my $y    = shift;

	return 1
	  if ( $self->x1 < $x && $x < $self->x2 )
	  && ( $self->y1 < $y && $y < $self->y2 );
	return 0;
}

# =================================================================
# set_colour ( $colour)
# =================================================================

=head2 set_colour

fills the block with specified colour

Colour string can be of type "#rrggbb" or a valid unix colour name

B<Parameters>

$colour (default "mistyrose3") 

B<Returns>

block

=cut

sub set_colour {
	my $self = shift;
	my $colour = shift || "mistyrose3";

	my $c = Colour->new($colour);
	$self->canvas->itemconfigure( $self->id, -fill => $c->string );
	return $self;
}

# =================================================================
# remove_colour ()
# unfill ()
# =================================================================

=head2 set_colour | unfill

removes any colour from the block

B<Returns>

block

=cut

sub unfill { return remove_colour(@_); }

sub remove_colour {
	my $self = shift;
	$self->canvas->itemconfigure( $self->id, -fill => '' );
	return $self;
}

# =================================================================
# getters and setters
# =================================================================

=head2 getters / setters

    id

    day

    start
    
    view
    
    canvas
    
    x1
    
    y1
    
    x2
    
    y2

=cut

sub id {
	my $self = shift;
	$self->{-id} = shift if @_;
	return $self->{-id};
}

sub day {
	my $self = shift;
	$self->{-day} = shift if @_;
	return $self->{-day};
}

sub start {
	my $self = shift;
	$self->{-start} = shift if @_;
	return $self->{-start};
}

sub view {
	my $self = shift;
	$self->{-view} = shift if @_;
	return $self->{-view};
}

sub canvas {
	my $self = shift;
	$self->{-canvas} = shift if @_;
	return $self->{-canvas};
}

sub x1 {
	my $self = shift;
	$self->{-x1} = shift if @_;
	return $self->{-x1};
}

sub y1 {
	my $self = shift;
	$self->{-y1} = shift if @_;
	return $self->{-y1};
}

sub x2 {
	my $self = shift;
	$self->{-x2} = shift if @_;
	return $self->{-x2};
}

sub y2 {
	my $self = shift;
	$self->{-y2} = shift if @_;
	return $self->{-y2};
}

#
sub Get_day_start_duration {
	my $class  = shift;
	my $chosen = shift;
	my @x      = @$chosen;
	return unless @x;

	my $day   = $x[0]->day;
	my $start = $x[0]->start;
	my $size  = scalar @x;

	foreach my $i ( @x ) {
		my $temp = $i->start;
		if ( $temp < $start ) {
			$start = $temp;
		}
	}

	return ( $day, $start, $size / 2.0 );
}

# =================================================================
# footer
# =================================================================

=head1 AUTHOR

Sandy Bultena, Alex Oxorn

=head1 COPYRIGHT

Copyright (c) 2020, Sandy Bultena, Alex Oxorn. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;
