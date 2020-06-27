#!/usr/bin/perl
use strict;
use warnings;

package Time_slot;
use Carp qw (confess cluck);
use Data::Dumper;

=head1 NAME

Time_slot - a time slot (day, start, duration) 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Time_slot;
    
    my $time_slot = Time_slot->new (-day=>"Wed",
                                    -start=>"9:30",
                                    -duration=>1.5,
                                    -movable=>1);

=head1 DESCRIPTION

A time slot is specified by a day of the week, start time, 
length (in hours), and a whether or not it is allowed to move.

Example:  the 'Block' object has a time slot used for teaching,
whilst a 'Lab' object has a time slot indicating when it is
not available.

=head1 METHODS

=cut

# =================================================================
# Class/Global Variables
# =================================================================
our $Max_id = 0;
our %week =
  ( mon => 1, tue => 2, wed => 3, thu => 4, fri => 5, sat => 6, sun => 7 );
our $Max_hour_div = 2;
our %reverse_week = map { $week{$_}, $_ } keys %week;
our $Default_day = 'mon';
our $Default_start = '8:00';
our $Default_duration = 1.5;

# =================================================================
# new
# =================================================================

=head2 new ()

creates and returns a time_slot object

B<Parameters>

-day => 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'

-start => start time using 24 h clock (i.e 1pm is "13:00")

-duration => how long does this class last, in hours

B<Returns>

Time_slot object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;

    confess "Bad inputs\n" if @_ % 2;
    my %inputs = @_;

    # process inputs
    my $day      = $inputs{-day}      || $Default_day;
    my $start    = $inputs{-start}    || "8:00";
    my $duration = $inputs{-duration} || "1.5";
    $duration = 8 if $duration > 8;
    my $movable = exists $inputs{-movable} ? $inputs{-movable} : 1;

    # create the object
    my $self = {};
    bless $self, $class;
    $self->{-id} = ++$Max_id;
    $self->day($day);
    $self->start($start);
    $self->duration($duration);
    $self->movable($movable);

    return $self;
}

# =================================================================
# id
# =================================================================

=head2 id ()

Returns the unique id for this time_slot object

=cut

sub id {
    my $self = shift;
    return $self->{-id};
}

# =================================================================
# day
# =================================================================

=head2 day ( [day] )

Get/set the day of the week for this time_slot

=cut

sub day {
    my $self = shift;
    if (@_) {
        my $day = shift;
        $day = substr( lc($day), 0, 3 );
        
        # if bad input, set to monday
        if ($day =~ /^mon|tue|wed|thu|fri|sat|sun/i) {
            $self->{-day} = $day;
        		$self->day_number( $week{$day} );
        }
        elsif ($day =~ /^[1-7]$/){
        		$self->day_number($day);
        		$self->{-day} = $reverse_week{$day};
        }else{
        		cluck "<$day>: invalid day specified... setting to $Default_day\n";
            $day = $Default_day;
            $self->{-day} = $day;
        		$self->day_number( $week{$day} );
        }

        
    }
    return $self->{-day};
}

# =================================================================
# start
# =================================================================

=head2 start ( [time] )

Get/set start time of time_slot, in 24hr clock

=cut

sub start {
    my $self = shift;

    if (@_) {
        my $start = shift;
        
        unless ($start =~ /^[12]?[0-9]:(00|15|30|45)$/) {
            cluck "<$start>: invalid start time, "."changed to $Default_start\n";
            $start = $Default_start;
        }

        $self->{-start} = $start;
        my ( $hr, $min ) = $start =~ /^(\d+?):(\d+)$/;
        $self->start_number( $hr + $min / 60 );
    }

    return $self->{-start};
}

# =================================================================
# end
# =================================================================

=head2 end ( [time] )

Gets the end time in 24 hour clock

=cut

sub end {
    my $self = shift;
    my $start = $self->start_number;
    my $end = $start + $self->duration;
    my $hr = sprintf("%2i",int( $end ));
    my $min = sprintf("%02i",int( ($end*60)%60));
    return "$hr:$min";
}

# =================================================================
# duration
# =================================================================

=head2 duration ( [duration] )

Gets and sets the length of the time_slot, in hours

=cut

sub duration {
    my $self = shift;
    if (@_) {
        no warnings;
        my $duration = shift;
        if($duration < .25 && $duration > 0){
        		$duration = .5;
        }else{    	
	        my $temp = 2 * $duration;
	        my $rounded = int($temp + 0.5);
	        $duration = $rounded/2;
        }
        $duration = 8 if $duration > 8;
        if ($duration <= 0) {
            cluck "<$duration>: invalid duration, "."changed to $Default_duration" ;
            $duration = $Default_duration;
        }
        $self->{-duration} = $duration;
    }
    return $self->{-duration};
}

# =================================================================
# movable
# =================================================================

=head2 movable ( [true | false] )

Gets and sets the course section object which contains this time_slot

=cut

sub moveable { movable(@_) }

sub movable {
    my $self = shift;
    $self->{-movable} = shift if @_;
    return $self->{-movable};
}

# =================================================================
# start_number
# =================================================================

=head2 start_number 

Sets or returns the start time in hours 
(i.e. 1:30 pm = 13.5 hours)

This time info is set every time the start method is
invoked on the object.  Modifying this hash directly I<does not>
modify the value stored in 'start'.

To set the time according to this data (to the nearest grid level), 
use the method C<snap_to_time>

=cut

sub start_number {
    my $self = shift;
    $self->{-start_number} = shift if @_;
    return $self->{-start_number};

}

# =================================================================
# day_number
# =================================================================

=head2 day_number 

Returns a hash ref that defines the day of the week as a real number,
starting from monday 
(i.e. tues = 2.0)

This info is set every time the method is
invoked on the object.  Modifying directly I<does not>
modify the values stored in 'day'.

To set the day according to the data in this hash, use the
method C<snap_to_day>

=cut

sub day_number {
    my $self = shift;
    $self->{-day_number} = shift if @_;
    return $self->{-day_number};
}



# =================================================================
# snap_to_time
# =================================================================

=head2 snap_to_time 

Takes the start_number, and converts it to the nearest fraction of
an hour (if $Max_hour_div = 2, then snaps to every 1/2 hour).

Resets the 'start' property to the new clock time

Returns true if the new time is different than the previous time

=cut

sub snap_to_time {
    my $self  = shift;
    my $hour  = $self->_snap_to_time(@_);
    my $min   = int( ( $hour - int($hour) ) * 60 );
    my $start = int($hour) . ":" . sprintf( "%02d", $min );

    my $changed = 0;
    if ($start ne $self->start) {
    		$changed = 1;
    }
    $self->start($start);
    return $changed;
}

sub _snap_to_time {
    my $self = shift;

    my $min_time = shift || 8;
    my $max_time = shift || 18;

    my $Max_hour_div = $Max_hour_div < 1 ? 1 : $Max_hour_div;

    my $rhour = $self->start_number;
    my $start = "";

    # get hour and fractional hour
    my $hour = int($rhour);
    my $frac = $rhour - $hour;

    # create array of allowed fractions
    my @fracs;
    foreach my $i ( 0 .. $Max_hour_div ) {
        push @fracs, $i / $Max_hour_div;
    }

    # sort according to which one is closest
    # to our fraction
    my @sorted_frac = sort { abs( $a - $frac ) <=> abs( $b - $frac ) } @fracs;

    # add hour fraction to hour
    $hour = $hour + $sorted_frac[0];

    # adjust hour to minimum or maximum
    $hour = $min_time if $hour < $min_time;
    $hour = $max_time - $self->duration if $hour > $max_time - $self->duration;

    return $hour;
}

# =================================================================
# snap_to_day
# =================================================================

=head2 snap_to_day 

Takes the start_day, and converts it to the nearest day

Resets the 'day' property to the appropriate string

Returns true if the new time is different than the previous time

=cut

sub snap_to_day {
    my $self = shift;
    my $day  = $self->_snap_to_day(@_);
    
    my $changed = 0;
    if ($reverse_week{$day} ne $self->day) {
    		$changed = 1;
    }
    $self->day( $reverse_week{$day} );
    return $day;
}

sub _snap_to_day {
    my $self = shift;
    my $min  = shift || 1;
    my $max  = shift || 7;

    my $rday = $self->day_number;

    my $day = ( $rday == int($rday) ) ? $rday : int( $rday + .5 );
    $day = $min unless $day;
    $day = $day > $max ? $max : $day;
    return $day;
}


# =================================================================
# conflicts
# =================================================================

=head2 conflicts

Test that the current Time_slot conflicts with another time slot. 

=cut

sub conflicts_time {
    my $self = shift;
    my $rhs = shift;

    # detect time collisions up to this error factor, also useful for graphical applications
    # that require a small error threshold when moving a block into place.
    my $delta = 0.05;

    # detect date collisions
    return 0 if (abs($self->day_number - $rhs->day_number) >= 1 - $delta);

    # calculate the start/end for each block with the error factor removed.
    my $selfStart = $self->start_number + $delta;
    my $selfEnd   = $self->start_number + $self->duration - $delta;
    my $rhsEnd    = $rhs->start_number + $rhs->duration - $delta;
    my $rhsStart  = $rhs->start_number + $delta;
   
    return ($selfStart < $rhsEnd && $rhsStart < $selfEnd);
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
