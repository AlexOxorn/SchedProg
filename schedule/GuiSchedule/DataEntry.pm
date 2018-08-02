#!/usr/bin/perl
use strict;
use warnings;

package DataEntry;
use FindBin;
use Carp;
use lib "$FindBin::Bin/..";
use Tk::TableEntry;

=head1 NAME

DataEntry - provides methods/objects for entering schedule data manually 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;
my @Delete_queue;
my $guiSchedule;

# =================================================================
# new
# =================================================================

=head2 new ()

creates the basic Data Entry (simple matrix)

B<Returns>

data entry object

=cut

# ===================================================================
# new
# ===================================================================
sub new {
    my $class     = shift;
    my $frame     = shift;
    my $obj       = shift;
    my $type      = shift;
    my $schedule  = shift;
    my $dirty_ptr = shift;
    $guiSchedule = shift;
    undef @Delete_queue;

    my $self = {
                 -dirty    => $dirty_ptr,
                 -type     => $type,
                 -obj      => $obj,
                 -frame    => $frame,
                 -schedule => $schedule
               };

    # ---------------------------------------------------------------
    # get objects to process?
    # ---------------------------------------------------------------
    my @objs = $obj->list;
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
        push @disabled, qw(1 1 1 1);
        push @sizes,    qw(4 20 20 8);
        $sortby = 'lastname';
    }

    if ( $type eq 'Lab' ) {
        push @methods, qw(id number descr);
        push @titles, ( 'id', 'room', 'description' );
        push @disabled, qw(1 1 1 );
        push @sizes,    qw(4 7 40 );
        $sortby = 'number';
    }

    if ( $type eq 'Stream' ) {
        push @methods, qw(id number descr);
        push @titles, ( 'id', 'number', 'description' );
        push @disabled, qw(1 1 1 );
        push @sizes,    qw(4 10 40 );
        $sortby = 'number';
    }

    $self->{-sortby}   = $sortby;
    $self->{-methods}  = \@methods;
    $self->{-disabled} = \@disabled;

    # ---------------------------------------------------------------
    # create the table entry object
    # ---------------------------------------------------------------
    $de = $frame->TableEntry(
                              -rows      => 1,
                              -columns   => scalar(@titles),
                              -titles    => \@titles,
                              -colwidths => \@sizes,
                              -disabled  => \@disabled,
                              -delete    => [ \&delete_obj, $self ],
                            )->pack( -side => 'top', -expand => 1, -fill => 'both' );

    $self->{-table} = $de;
    _fill_table($self);

    # ---------------------------------------------------------------
    # create the edit and save buttons
    # ---------------------------------------------------------------
    my $bf = $frame->Frame()->pack(
                                    -fill  => 'y',
                                    -side  => 'bottom',
                                    -ipady => 10
                                  );

    my $edit = $bf->Button(
                            -text    => 'Edit',
                            -width   => 15,
                            -command => [ \&edit, $self ]
                          )->pack( -side => 'left' );
    my $save = $bf->Button(
                            -text    => 'Apply Changes',
                            -width   => 15,
                            -command => [ \&save, $self ],
                            -state   => 'disabled'
                          )->pack( -side => 'left' );

    # create the object
    $self->{-id}          = $Max_id++;
    $self->{-edit_button} = $edit;
    $self->{-save_button} = $save;
    $self->{-data_obj}    = $de;
    $self->{-methods}     = \@methods;

    return bless $self, $class;
}

# =================================================================
# refresh the tables
# =================================================================
sub refresh {
    my $self = shift;
    my $obj  = shift;
    $self->{-obj} = $obj if $obj;

    undef @Delete_queue;
    $self->{-table}->empty();
    $self->_fill_table();
    $self->no_edit();
}

# =================================================================
# fill table with data
# =================================================================
sub _fill_table {
    my $self    = shift;
    my $de      = $self->{-table};
    my $sortby  = $self->{-sortby};
    my $objs    = $self->{-obj}->list;
    my $methods = $self->{-methods};

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
    $self->{-table}->add_empty_row($row);

}

# =================================================================
# Disable Editing
# =================================================================
sub no_edit {
    my $self = shift;

    $self->{-save_button}->configure( -state => 'disabled' );
    my @disabled;
    foreach my $c ( 1 .. $self->{-data_obj}->columns ) {
        push @disabled, 1;
    }
    $self->{-data_obj}->configure( -disabled => \@disabled );
    $self->{-data_obj}->update;
}

# =================================================================
# Go to Edit Mode
# =================================================================
sub edit {
    my $self = shift;
    $self->{-save_button}->configure( -state => 'normal' );

    my @disabled = (1);
    foreach my $c ( 2 .. $self->{-data_obj}->columns ) {
        push @disabled, 0;
    }
    $self->{-data_obj}->configure( -disabled => \@disabled );
}

# =================================================================
# Save updated data
# =================================================================
sub save {
    my $self = shift;
    $self->no_edit;
    my $schedule = $self->{-schedule};

    # read data from data object
    foreach my $r ( 1 .. $self->{-data_obj}->rows ) {
        my @data = $self->{-data_obj}->read_row($r);

        # if this is an empty row, do nothing
        next if @data == grep { !$_ } @data;

        # if this row has an ID, then we need to update the
        # corresponding object
        if ( defined $data[0] && !( $data[0] eq '' ) ) {
            no strict 'refs';
            my $obj = $self->{-obj};
            my $o   = $obj->get( $data[0] );
            my $col = 1;
            foreach my $method ( @{ $self->{-methods} } ) {
                $o->$method( $data[ $col - 1 ] );
                $col++;
            }
        }

        # if this row does not have an ID, then we need to create
        # corresponding object
        else {
            my $obj = $self->{-obj};
            unless ( $obj->isa('Labs') && $obj->get_by_number( $data[1] ) ) {
                my %parms;
                my $col = 1;
                foreach my $method ( @{ $self->{-methods} } ) {
                    $parms{ '-' . $method } = $data[ $col - 1 ];
                    $col++;
                }
                my $new = $self->{-type}->new(%parms);
                $obj->add($new);
            }
        }
    }

    # go through delete queue and apply changes
    while ( my $d = shift @Delete_queue ) {

        no strict 'refs';
        my $obj = shift @$d;
        my $o   = shift @$d;

        if ($o) {
            if ( $obj->isa('Teachers') ) {
                $schedule->remove_teacher($o);
            }
            elsif ( $obj->isa('Streams') ) {
                $schedule->remove_stream($o);
            }
            elsif ( $obj->isa('Labs') ) {
                $schedule->remove_lab($o);
            }

        }
    }

    # now we have to update the id's in the rows, or else it just won't
    # work for other things
    $self->refresh;

    $self->set_dirty();

}

# =================================================================
# delete object
# =================================================================
sub delete_obj {
    my $self = shift;
    my $data = shift;

    # create a queue so that we can delete the objects
    # ONLY when the user 'applies changes'
    push @Delete_queue, [ $self->{-obj}, $self->{-obj}->get( $data->[0] ) ];
}

# =================================================================
# set dirty flag
# =================================================================
sub set_dirty {
    my $self = shift;
    ${ $self->{-dirty} } = 1;
    $guiSchedule->destroy_all;
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

