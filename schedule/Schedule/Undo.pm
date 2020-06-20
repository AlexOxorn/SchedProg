#!/usr/bin/perl
use strict;
use warnings;

package Undo;
use FindBin;
use lib "$FindBin::Bin/..";
use Schedule::Teacher;
use Schedule::Lab;
use Schedule::Stream;

=head1 NAME

Undo - Holds info about a block so that it can be used as an "undo"

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    my $Schedule    = Schedule->read('myschedule_file.yaml');

    my $teacher = $Schedule->teachers()->get_by_name("Sandy","Bultena");
    my @blocks = $Schedule->blocks_for_teachers($teacher);
    my @undos = ();
    
    # save block[0] before modifying it
    push @undos, Undo->new( $block->id, $block->start,
                            $block->day, $teacher, "Day/Time" );


=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;

# =================================================================
# new
# =================================================================

=head2 new ()

creates a GuiSchedule object

B<Parameters>

-block_id => ID of the Block this Undo is associated with 

-origin_start => The original start time of the block before moving

-origin_day => The original day of the block before moving

-origin_obj => The object the block was associated with before moving (i.e. Teacher/Lab/Stream)

-move_type => The type of movement this block made (i.e. within schedule, across schedules)

-new_obj => The object the block is currently associated with after moving (i.e. new Teacher/Lab/Stream)

B<Returns>

Undo object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
	my $this = shift;
	my $block_id = shift;
	my $origin_start = shift;
	my $origin_day = shift;
	my $origin_obj = shift;
	my $move_type = shift;
	my $new_obj = shift;

	my $self = {};
	bless $self;
	$self->{-id} = $Max_id++;
	$self->block_id($block_id);
	$self->origin_start($origin_start);
	$self->origin_day($origin_day);
	$self->origin_obj($origin_obj);
	$self->new_obj($new_obj);
	$self->move_type($move_type);
	
	return $self;
}

=head2 id ()

Returns the unique id for this Undo object.

=cut

sub id {
	my $self = shift;
	return $self->{-id};

}
=head2 block_id ( [Block ID] )

Get/sets the Block ID for the Block this Undo is for.

=cut

sub block_id {
	my $self = shift;
	$self->{-block_id} = shift if @_;
	return $self->{-block_id};
}

=head2 origin_start ( [Start Time] )

Get/sets the start time for the Block this Undo is for.

=cut

sub origin_start {
	my $self = shift;
	$self->{-origin_start} = shift if @_;
	return $self->{-origin_start};
}

=head2 origin_day ( [Day Number] )

Get/sets the day number for the Block this Undo is for.

=cut

sub origin_day {
	my $self = shift;
	$self->{-origin_day} = shift if @_;
	return $self->{-origin_day};
}

=head2 origin_object ( [Teacher/Lab/Stream Object] )

Get/sets the Teacher/Lab/Stream object for the Block this Undo is for.

=cut

sub origin_obj {
	my $self = shift;
	$self->{-origin_obj} = shift if @_;
	return $self->{-origin_obj};
}

=head2 move_type ( [String] )

Get/sets the move type string for the Block this Undo is for.

=cut

sub move_type {
	my $self = shift;
	$self->{-move_type} = shift if @_;
	return $self->{-move_type};
}

=head2 new_obj ( [Teacher/Lab/Stream Object] )

Get/sets the new Teacher/Lab/Stream object for the Block this Undo is for.

=cut

sub new_obj {
	my $self = shift;
	$self->{-new_obj} = shift if @_;
	return $self->{-new_obj};
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
