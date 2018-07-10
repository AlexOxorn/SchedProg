#!/usr/bin/perl
use strict;
use warnings;

package GuiBlocks;
use FindBin;
use lib "$FindBin::Bin/..";
use PerlLib::Colours;

=head1 NAME

GuiBlock - describes the visual representation of a Block

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

	use GuiSchedule::GuiBlocks;
	use GuiSchedule::ViewV2;
	my $mw = MainWindow->new;
	my @blocks =  
	my $View = ViewV2->new($mw, \@blocks);
    my @coords = [10, 15, 15, 15];
    my $block = $blocks[0];
    my $guiBlocks = GuiBlocks->new($mw, $block, @coords);
    
    $guiBlocks->change_colour("red");
    
    print "This is the GuiBlock for ".$guiBlocks->block."\n";

=head1 DESCRIPTION

Describes a GuiBlock

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;
our $Edge   = 5;

# =================================================================
# new
# =================================================================

=head2 new ()

creates, draws and returns a GuiBlocks object

B<Parameters>

-view => View the GuiBlock will be drawn on

-block => Block to turn into a GuiBlock

-coords => Where to draw the GuiBlock on the View

B<Returns>

GuiBlock object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
	my $this   = shift;
	my $view   = shift;
	my $block  = shift;
	my $coords = shift;

	# set the colour and pixel width of edge
	my $colour = shift || '#abcdef';
	my $scale  = shift;
	my $edge   = shift || $Edge;
	$Edge = $edge;
	
	

	# get canvas from view to draw on
	my $canvas = $view->canvas;
	$colour = Colour->string($colour);

	# get needed block information
	my $blockNum      = $block->section->course->number || " ";
	my $blockSec       = " (" . $block->section->number . ")";
	my @teachers       = $block->teachers;
	my $blockTeacher   = sprintf( join( "\n", @teachers ) ) || "";
	my @labs           = $block->labs;
	my $blockLab       = sprintf( join( ",", @labs ) ) || "";
	my $blockDuration  = $block->duration;
	my $blockStartTime = $block->start_number;
	my @streams = $block->section->streams;
	my $blockStreams = sprintf( join( ",", @streams ) ) || "";
	
	my $count = 0;
	my $ignoreStream = 0;

	# change what to display on GuiBlock depending on View size
	if($scale <= 0.75) {
		$blockTeacher = "";
		$count = 0;
		foreach my $teacher (@teachers) {
			# only add teacher to GuiBlock if current schedule does not belong to current teacher
			if($view->type eq "teacher") {
				if($view->obj->id != $teacher->id) {
					$blockTeacher = $blockTeacher.substr($teacher->firstname, 0, 1);
					$blockTeacher = $blockTeacher.substr($teacher->lastname, 0, 1).", ";
					$count++;
					# added teachers, don't display stream on GuiBlock
					$ignoreStream = 1;
				}
			} else {
				$blockTeacher = $blockTeacher.substr($teacher->firstname, 0, 1);
				$blockTeacher = $blockTeacher.substr($teacher->lastname, 0, 1).", ";
				$count++;
				# added teachers, don't display stream on GuiBlock
				$ignoreStream = 1;
			}
		}
		# remove last comma and space characters from teacher string
		$blockTeacher = substr($blockTeacher, 0, length($blockTeacher) - 2);
		# add ellipsis to end of teacher string as necessary
		if ($scale == 0.5 && $count >= 3) {
			$blockTeacher = substr($blockTeacher, 0, 7)."...";	
		} elsif ($count >= 4) {
			$blockTeacher = substr($blockTeacher, 0, 11)."...";	
		}
		$blockLab = "";
		$count = 0;
		foreach my $lab (@labs) {
			# only add lab to GuiBlock if current schedule does not belong to current lab
			if($view->type eq "lab") {
				if($view->obj->id != $lab->id) {
					$blockLab = $blockLab.$lab->number.", ";
					$count++;
					# added labs, don't display stream
					$ignoreStream = 1;
				}
			} else {
				$blockLab = $blockLab.$lab->number.", ";
				$count++;
				# added labs, don't display stream
				$ignoreStream = 1;
			}
		}
		# remove last comma and space characters from lab string
		$blockLab = substr($blockLab, 0, length($blockLab) - 2);
		# add ellipsis to end of lab string as necessary
		if ($scale == 0.5 && $count >= 3) {
			$blockLab = substr($blockLab, 0, 7)."...";	
		} elsif ($count >= 4) {
			$blockLab = substr($blockLab, 0, 11)."...";	
		}
		$blockStreams = "";
		$count = 0;
		# only add streams if no teachers or labs, or GuiBlock can fit all info (i.e. duration of 2 hours or more)
		if(!$ignoreStream || $blockDuration >= 2) {
			foreach my $stream (@streams) {
				# only add stream to GuiBlock if current schedule does not belong to current stream
				if($view->type eq "stream") {
					if($view->obj->id != $stream->id) {
						$blockStreams = $blockStreams.$stream->number.", ";
						$count++;
					}
				} else {
					$blockStreams = $blockStreams.$stream->number.", ";
					$count++;
				}
			}
			# remove last comma and space characters from stream string
			$blockStreams = substr($blockStreams, 0, length($blockStreams) - 2);
			# add ellipsis to end of stream string as necessary
			if ($scale == 0.5 && $count >= 3) {
				$blockStreams = substr($blockStreams, 0, 7)."...";	
			} elsif ($count >= 4) {
				$blockStreams = substr($blockStreams, 0, 11)."...";	
			}
		}
	}

	# remove program number from course number (i.e. 420-506 becomes 506)
	if($scale == 0.5) {
		$blockNum =~ s/.*\-//g;
	}
	
	# set display text to everything
	my $blockText = "$blockNum$blockSec\n$blockTeacher\n$blockLab\n$blockStreams";
	# changes text to hold only the information that is defined
	if($blockTeacher eq "") {
		if($blockLab eq "") {
			if($blockStreams eq "") {
				$blockText = "$blockNum$blockSec";
			} else {
				$blockText = "$blockNum$blockSec\n$blockStreams";	
			}
		} else {
			if($blockStreams eq "") {
				$blockText = "$blockNum$blockSec\n$blockLab";	
			} else {
				$blockText = "$blockNum$blockSec\n$blockLab\n$blockStreams";	
			}
		}	
	} else {
		if($blockLab eq "") {
			if($blockStreams eq "") {
				$blockText = "$blockNum$blockSec\n$blockTeacher";	
			} else {
				$blockText = "$blockNum$blockSec\n$blockTeacher\n$blockStreams";	
			}
		} else {
			if($blockStreams eq "") {
				$blockText = "$blockNum$blockSec\n$blockTeacher\n$blockLab";	
			} else {
				$blockText = "$blockNum$blockSec\n$blockTeacher\n$blockLab\n$blockStreams";	
			}	
		}	
	}

	
	#create rectangle
	my $rectangle = $canvas->createRectangle(
		@$coords,
		-fill    => $colour,
		-outline => $colour
	);

	# shade edges of guiblock rectangle
	my @lines;
	my ( $x1, $y1, $x2, $y2 ) = @$coords;
	my ( $light, $dark, $textcolour ) = _get_colour_shades( $colour, $edge );
	foreach my $i ( 0 .. $edge - 1 ) {
		push @lines,
		  $canvas->createLine( $x2 - $i, $y1 + $i, $x2 - $i, $y2 - $i,
			$x1 + $i, $y2 - $i, -fill => $dark->[$i] );
		push @lines,
		  $canvas->createLine( $x2 - $i, $y1 + $i, $x1 + $i, $y1 + $i,
			$x1 + $i, $y2 - $i, -fill => $light->[$i] );
	}

	# set text
	my $text = $canvas->createText(
		( $x1 + $x2 ) / 2, ( $y1 + $y2 ) / 2,
		-text => $blockText,
		-fill => $textcolour
	);
	my @coords = $canvas->coords($rectangle);

	# group rectange and text to create guiblock, so that they both move as one on UI
	my $group = $canvas->createGroup( [ 0, 0 ],
		-members => [ $rectangle, $text, @lines ] );

	# create object
	my $self = {};
	bless $self;
	$self->{-id} = $Max_id++;
	$self->block($block);
	$self->view($view);
	$self->coords( \@coords );
	$self->colour($colour);
	$self->rectangle($rectangle);
	$self->text($text);
	$self->group($group);
	$self->is_controlled(0);

	# return object
	return $self;
}

# =================================================================
# change the colour of the guiblock
# =================================================================

=head2 change_colour ($colour)

Change the colour of the guiblock (including text and shading)

=cut

sub change_colour {
	my $self   = shift;
	my $colour = shift;
	$colour = Colour->string($colour);

	my $cn    = $self->view->canvas;
	my $group = $self->group;

	my ( $light, $dark, $textcolour ) = _get_colour_shades( $colour, $Edge );

	my ( $rect, $text, @lines ) = $cn->itemcget( $group, -members );
	$cn->itemconfigure( $rect, -fill => $colour, -outline => $colour );
	$cn->itemconfigure( $text, -fill => $textcolour );

	foreach my $i ( 0 .. @lines ) {
		$cn->itemconfigure( $lines[ $i * 2 ],     -fill => $dark->[$i] );
		$cn->itemconfigure( $lines[ $i * 2 + 1 ], -fill => $light->[$i] );
	}
}

# =================================================================
# get the shades of the colour
# =================================================================

=head2 _get_colour_shades ($colour, $edge)

Get the shading of the GuiBlock

=cut

sub _get_colour_shades {
	my $colour = shift;
	my $edge   = shift;
	my ( $h, $s, $l ) = Colour->hsl($colour);
	my $light_intensity = $l > .7 ? ( 1 - $l ) * 75 : 30 * .75;
	my $dark_intensity  = $l < .3 ? $l * 75         : 30 * .75;

	my @light;
	my @dark;
	my $textcolour = "black";
	unless ( Colour->isLight($colour) ) {
		$textcolour = "white";
	}
	foreach my $i ( 0 .. $edge - 1 ) {
		my $lfactor = ( 1 - ( $i / $edge ) ) * $light_intensity;
		my $dfactor = ( 1 - ( $i / $edge ) ) * $dark_intensity;
		push @light, Colour->lighten( $lfactor, $colour );
		push @dark, Colour->darken( $dfactor, $colour );
	}
	return \@light, \@dark, $textcolour;
}

# =================================================================
# getters/setters
# =================================================================

=head2 id ()

Returns the unique id for this guiblock object

=cut

sub id {
	my $self = shift;
	return $self->{-id};
}

=head2 block ( [block] )

Get/set the block for this guiblock

=cut

sub block {
	my $self = shift;
	$self->{-block} = shift if @_;
	return $self->{-block};
}

=head2 view ( [view] )

Get/set the view for this guiblock

=cut

sub view {
	my $self = shift;
	$self->{-view} = shift if @_;
	return $self->{-view};
}

=head2 coords ( [coords] )

Get/set the coordinates for this guiblock

=cut

sub coords {
	my $self = shift;
	$self->{-coords} = shift if @_;
	return $self->{-coords};
}

=head2 colour ( [colour] )

Get/set the colour for this guiblock

=cut

sub colour {
	my $self = shift;
	if (@_) {
		$self->{-colour} = shift;
		my $canvas    = $self->view->canvas;
		my $rectangle = $self->rectangle;
		$canvas->itemconfigure( $rectangle, -fill => $self->{-colour} );
	}
	return $self->{-colour};
}

=head2 rectangle ( [rectangle object] )

Get/set the rectangle object for this guiblock

=cut

sub rectangle {
	my $self = shift;
	$self->{-rectangle} = shift if @_;
	return $self->{-rectangle};
}

=head2 text ( [text object] )

Get/set the text object for this guiblock

=cut

sub text {
	my $self = shift;
	$self->{-text} = shift if @_;
	return $self->{-text};
}

=head2 group ( [group] )

Get/set the group for this guiblock. The group is what moves on the canvas.

=cut

sub group {
	my $self = shift;
	$self->{-group} = shift if @_;
	return $self->{-group};
}

=head2 is_controlled ( [boolean] )

Get/set the group for this guiblock. The group is what moves on the canvas.

=cut

sub is_controlled {
	my $self = shift;
	$self->{-is_controlled} = shift if @_;
	return $self->{-is_controlled};
}

# =================================================================
# footer
# =================================================================

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;
