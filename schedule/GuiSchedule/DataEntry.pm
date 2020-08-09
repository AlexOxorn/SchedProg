#!/usr/bin/perl
use strict;
use warnings;

package DataEntry;
use FindBin;
use Carp;
use lib "$FindBin::Bin/..";
use Tk::TableEntry;

=head1 NAME

DataEntry - provides methods/objects for entering teachers/labs/etc data  

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    use GuiSchedule::GuiSchedule;
    use GuiSchedule::DataEntry;
    use Tk;
    
    my $Dirtyflag   = 0;
    my $mw          = MainWindow->new();
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $guiSchedule = GuiSchedule->new( $mw, \$Dirtyflag, \$Schedule );
    
    # create a data entry list
    # NOTE: requires $guiSchedule just so that it can update
    #       the views if data has changed (via the dirty flag)
    
    my $de = DataEntry->new( $mw, $Schedule->teachers, 'Teacher',
                    $Schedule, \$Dirtyflag, $guiSchedule );

=head1 DESCRIPTION

A generic data entry widget

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;
my @Delete_queue;
my $guiSchedule;
my $room_index = 1;
my $id_index   = 0;

# =================================================================
# new
# =================================================================

=head2 new ()

creates the basic Data Entry (simple matrix)

B<Inputs>

=over

=item * Tk frame where to draw data entry widgets

=item * List of objects (teachers or labs, or streams)

=item * What type of data object ("Teacher", "Lab", "Stream")

=item * the schedule object

=item * reference to the dirty pointer

=item * guiSchedule - the object that manages the views

=back

B<Returns>

data entry object

=cut

# ===================================================================
# new
# ===================================================================
sub new {
    my $class    = shift; # class
    my $frame    = shift; # frame where new GUI stuff is attached to
    my $list_obj = shift; # composite list object (teachers, labs, streasm, etc)
    my $schedule = shift; # the actual schedule object
    my $dirty_ptr = shift;    # has the data changed
    $guiSchedule = shift;     # the object containing all GUI stuff
    undef @Delete_queue;

    my $type;
    if ( $list_obj->isa("Teachers") ) {
        $type   = "Teacher";
    }
    elsif ( $list_obj->isa("Labs") ) {
        $type   = "Lab";
    }
    else {
        $type   = "Stream";
    }
    my $self = {
                 -dirty    => $dirty_ptr,
                 -type     => $type,
                 -list_obj => $list_obj,
                 -frame    => $frame,
                 -schedule => $schedule
               };

    # ---------------------------------------------------------------
    # get objects to process?
    # ---------------------------------------------------------------
    my @objs = $list_obj->list;
    my $rows = scalar(@objs);

    # ---------------------------------------------------------------
    # what are the columns?
    # ---------------------------------------------------------------
    my @methods;
    my @titles;
    my @disabled;
    my @sizes;
    my $sortby;
    my $delete_sub = sub { };
    my $de;

    if ( $type eq 'Teacher' ) {
        push @methods, qw(id firstname lastname release);
        push @titles, ( 'id', 'first name', 'last name', 'RT' );
        push @sizes, qw(4 20 20 8);
        $sortby = 'lastname';
    }

    if ( $type eq 'Lab' ) {
        push @methods, qw(id number descr);
        push @titles, ( 'id', 'room', 'description' );
        push @sizes, qw(4 7 40 );
        $sortby = 'number';
    }

    if ( $type eq 'Stream' ) {
        push @methods, qw(id number descr);
        push @titles, ( 'id', 'number', 'description' );
        push @sizes, qw(4 10 40 );
        $sortby = 'number';
    }

    $self->{-sortby}  = $sortby;
    $self->{-methods} = \@methods;
    $self->{-titles}  = \@titles;

    # ---------------------------------------------------------------
    # create the table entry object
    # ---------------------------------------------------------------
        $de = $frame->TableEntry(
                                  -rows      => 1,
                                  -columns   => scalar(@titles),
                                  -titles    => \@titles,
                                  -colwidths => \@sizes,
                                  -delete    => [ \&delete_obj, $self ],
                                )->pack( -side => 'top', -expand => 1, -fill => 'both' );

    @disabled = (1);
    foreach my $c ( 2 .. $de->columns ) {
        push @disabled, 0;
    }

    $de->configure( -disabled => \@disabled );

    # --------------------------------------------------------------------------
    # NOTE: If weird shit is happening, give up and use a 'Save' button
    # ... clicking the 'Delete' triggers a 'Leave'...
    # --------------------------------------------------------------------------
    $self->{-table} = $de;
    $self->{-table}->bind( '<Leave>', [ \&save, $self ] );

    # --------------------------------------------------------------------------
    # create the object
    # --------------------------------------------------------------------------
    $self->{-table}   = $de;
    $self->{-methods} = \@methods;

    bless $self, $class;
    my $row = $self->refresh;

    return $self;
}

# =================================================================
# refresh the tables
# =================================================================
sub refresh {
    my $self     = shift;
    my $list_obj = shift;
    $self->{-list_obj} = $list_obj if $list_obj;

    my $de      = $self->{-table};
    my $sortby  = $self->{-sortby};
    my $objs    = $self->{-list_obj}->list;
    my $methods = $self->{-methods};

    undef @Delete_queue;
    $de->empty();

    # ---------------------------------------------------------------
    # fill in the data
    # ---------------------------------------------------------------
    my $row = 1;
    foreach my $o ( sort { $a->$sortby cmp $b->$sortby } @$objs ) {
        my $col = 1;
        foreach my $method (@$methods) {
            $de->put( $row, $col, $o->$method() );
            $col++;
        }
        $row++;
    }
    $de->add_empty_row($row);
    return $row;

}

# =================================================================
# Save updated data
# =================================================================
my $currently_saving = 0;

sub save {

    # keep saving from possible recursion
    return if $currently_saving;
    $currently_saving++;

    # get inputs
    my $frame    = shift;
    my $self     = shift;
    my $schedule = $self->{-schedule};

    my $dirty_flag = 0;

    # read data from data object
    foreach my $r ( 1 .. $self->{-table}->rows ) {
        my @data = $self->{-table}->read_row($r);

        # if this is an empty row, do nothing
        next if @data == grep { !$_ } @data;

        # --------------------------------------------------------------------
        # if this row has an ID, then we need to update the
        # corresponding object
        # --------------------------------------------------------------------
        if ( defined $data[$id_index] && !( $data[$id_index] eq '' ) ) {

            no strict 'refs';
            my $list_obj = $self->{-list_obj};
            my $o        = $list_obj->get( $data[$id_index] );

            # loop over each method used to get info about this object
            my $col = 1;
            foreach my $method ( @{ $self->{-methods} } ) {
                no warnings;

               # set dirty flag if new data is not the same as the currently set
               # property
                $dirty_flag++ if $o->$method() ne $data[ $col - 1 ];

                # set the property to the data
                eval { $o->$method( $data[ $col - 1 ] ) };

                # just in case above fails, set data to property of object
                $self->{-table}->put( $r, $col, $o->$method() );
                $col++;
            }
        }

        # --------------------------------------------------------------------
        # if this row does not have an ID, then we need to create
        # corresponding object
        # --------------------------------------------------------------------
        else {
            my $list_obj = $self->{-list_obj};

            # create parameters to pass to new
            my %parms;
            my $col = 1;
            foreach my $method ( @{ $self->{-methods} } ) {
                $parms{ '-' . $method } = $data[ $col - 1 ];
                $col++;
            }

            # create new object and add to the list
            my $new;
            eval {
                $new = $self->{-type}->new(%parms);
                $list_obj->add($new);
            };

            # No errors?
            if ( $new && !$@ ) {
                $dirty_flag++;
                $self->{-table}->put( $r, $id_index + 1, $new->id() );
            }

        }
    }

    # ------------------------------------------------------------------------
    # go through delete queue and apply changes
    # ------------------------------------------------------------------------
    while ( my $d = shift @Delete_queue ) {

        no strict 'refs';
        my $list_obj = shift @$d;
        my $o        = shift @$d;

        if ($o) {
            $dirty_flag++;
            if ( $list_obj->isa('Teachers') ) {
                $schedule->remove_teacher($o);
            }
            elsif ( $list_obj->isa('Streams') ) {
                $schedule->remove_stream($o);
            }
            elsif ( $list_obj->isa('Labs') ) {
                $schedule->remove_lab($o);
            }

        }
    }

   # if there have been chnages, set global dirty flag, and do what is necessary
    $self->set_dirty() if $dirty_flag;
    $currently_saving = 0;

}

# =================================================================
# delete object
# =================================================================
sub delete_obj {
    my $self = shift;
    my $data = shift;

    # create a queue so that we can delete the objects
    # when the new info is saved

    my $obj = $self->{-list_obj}->get( $data->[$id_index] );
    push @Delete_queue, [ $self->{-list_obj}, $obj ] if $obj;
}

# =================================================================
# set dirty flag
# =================================================================
sub set_dirty {
    my $self = shift;
    ${ $self->{-dirty} } = 1;
    $guiSchedule->redraw_all_views if $guiSchedule;
}

# =================================================================
# footer
# =================================================================

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2020, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;

