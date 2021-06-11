#!/usr/bin/perl
use warnings;
use strict;
use FindBin;

package Tk::TableEntry;

use File::Find;
use lib "$FindBin::Bin/..";
use Tk::FindImages;
my $image_dir = Tk::FindImages::get_image_dir();

=head1 SYNOPSIS


=cut

# ===================================================================
# Create a tool for Entering text (excel style?)
# ===================================================================
use Carp;
our $VERSION = 2.01;

use Tk::widgets;
use Tk::Pane;

#use Tk::PNG;
use base qw/Tk::Frame/;

Construct Tk::Widget 'TableEntry';
my $ex_photo;

sub ClassInit {
    my ( $class, $mw ) = @_;
    $class->SUPER::ClassInit($mw);
}

# ===================================================================
# populate
# ===================================================================
sub Populate {
    my ( $t, $args ) = @_;

    # ---------------------------------------------------------------
    # create a scrolled pane
    # ---------------------------------------------------------------
    my $pane = $t->Scrolled(
                             "Pane",
                             Name        => 'TableEntry',
                             -scrollbars => 'oe',
                             -sticky     => 'nw',
                             -gridded    => 'xy',
                             -border     => 2,
                             -relief     => 'flat',
                           )->pack( -side => 'left', -fill => 'both' );
    $t->{-pane} = $pane;

    $pane->Subwidget('xscrollbar')->configure(
                                               -elementborderwidth => 2,
                                               -relief             => 'ridge',
                                               -width              => 12,
                                             );
    $pane->Subwidget('yscrollbar')->configure(
                                               -elementborderwidth => 2,
                                               -relief             => 'ridge',
                                               -width              => 12,
                                             );

    # ---------------------------------------------------------------
    # create defaults here, because ConfigSpecs doesn't set
    # those specifications until later, but we need this stuff
    # now
    # ---------------------------------------------------------------
    my %defaults = (
                     -rows      => 10,           # num of rows to start
                     -bg_entry  => '#ffffff',    # bg of entry widget
                     -columns   => 10,           # num of columns
                     -titles    => [],           # title of columns
                     -colwidths => [],           # width of columns
                     -disabled  => [],           # which cols are readonly
                     -defwidth  => 8,            # default width of columns
                   );

    my $bg = $t->toplevel->cget('-bg');

    # ---------------------------------------------------------------
    # define ConfigSpecs
    # ---------------------------------------------------------------
    $t->SUPER::Populate($args);
    $t->ConfigSpecs(
        -bg_entry => [ METHOD => 'bg_entry', 'Bg_Entry', $defaults{-bg_entry} ],
        -rows     => [ PASSIVE => 'rows',    'Rows',    $defaults{-rows} ],
        -columns  => [ PASSIVE => 'columns', 'Columns', $defaults{-columns} ],
        -titles   => [ METHOD  => 'titles',  'Titles',  $defaults{-titles} ],
        -disabled => [ METHOD  => 'titles',  'Titles',  $defaults{-disabled} ],
        -background => [ SELF     => 'background', 'Background', $bg ],
        -width      => [ SELF     => 'width',      'Width',      100 ],
        -height     => [ SELF     => 'height',     'Height',     200 ],
        -relief     => [ SELF     => 'relief',     'Relief',     'flat' ],
        -delete     => [ CALLBACK => 'delete',     'Delete',     sub { } ],
        -buttoncmd  => [ CALLBACK => 'buttoncmd',  'Buttoncmd',  undef ],
        -buttontext => [ PASSIVE  => 'buttontext', 'Buttontext', 'Go' ],
        -colwidths =>
          [ METHOD => 'colwidths', 'Colwidths', $defaults{-colwidths} ],
        -defwidth =>
          [ PASSIVE => 'defwidth', 'DefWidth', $defaults{-defwidth} ],
    );

    # ---------------------------------------------------------------
    # define the 'delete' image (or not)
    # ---------------------------------------------------------------
    eval {
        $ex_photo = $t->toplevel->Photo(
                                         -format => 'gif',
                                         -file   => "$image_dir/ex.gif"
                                       ) unless $ex_photo;
    };

    # ---------------------------------------------------------------
    # where we keep lookup info (widget to cell, cell to widget)
    # ---------------------------------------------------------------
    $t->{-reverse} = {};
    $t->{-lookup}  = [];

    # ---------------------------------------------------------------
    # configure this table entry, and then start drawing
    # ---------------------------------------------------------------
    my %configure = ( %defaults, %$args );
    $t->configure(%configure);
    $t->_init();

    return $t;

}
sub buttontext { }

# ===================================================================
# draw the widgets, etc
# ===================================================================
sub _init {
    my $t = shift;

    # create header row
    $t->_create_header_row;

    # add rows
    foreach my $row ( 1 .. $t->rows ) {
        $t->add_empty_row($row);
    }

    # calculate the width of the row, to set the pane width
    my $xtot = 0;
    foreach my $col ( 0 .. $t->columns ) {
        my $w = $t->get_widget( 1, $col );
        next unless $w;
        $xtot += $w->reqwidth + 12;
    }
    if ( $t->cget("-buttoncmd") ) {
        $xtot += 100;
    }

    $xtot += 2 * $t->cget('-border');
    $xtot += $t->pane->Subwidget('yscrollbar')->reqwidth;
    $t->pane->configure( -width => $xtot );
}

# ===================================================================
# basic getter/setters
# ===================================================================
sub pane {
    my $t = shift;
    return $t->{-pane};
}

sub rows {
    my $t = shift;
    return $t->cget('-rows');
}

sub row {
    my $t = shift;
    return $t->cget('-rows');
}

sub columns {
    my ($t) = @_;
    return $t->cget('-columns');
}

# ===================================================================
# change bg colour of entry boxes
# ===================================================================
sub bg_entry {
    my ( $t, $r ) = @_;

    if ( defined $r ) {
        $t->_configure( -bg_entry => $r );

        # if columns and rows are defined, then change
        # background of all entry widgets
        return unless $t->columns;
        return unless $t->rows;
        foreach my $c ( 1 .. $t->columns ) {
            foreach my $row ( 1 .. $t->rows ) {
                my $w = $t->get_widget( $row, $c );
                if ($w) {
                    $w->configure( -bg => $r );
                }
            }
        }
    }
    return $t->_cget('-bg_entry');
}

# ===================================================================
# set (or unset) disabled for all the entry widgets
# ===================================================================
sub disabled {
    my ( $t, $r ) = @_;
    if ( defined $r ) {
        $t->_configure( -bg_disabled => $r );

        # ----------------------------------------------------------
        # if columns and rows are defined, then change
        # state of all entry widgets
        # ----------------------------------------------------------
        return unless $t->columns;
        return unless $t->rows;
        foreach my $c ( 1 .. $t->columns ) {
            foreach my $row ( 1 .. $t->rows ) {
                my $w = $t->get_widget( $row, $c );
                if ($w) {
                    if ( $r->[ $c - 1 ] ) {
                        $w->configure( -state => 'disabled' );
                    }
                    else {
                        $w->configure( -state => 'normal' );
                    }
                }
            }
        }

        # ----------------------------------------------------------
        # disable the delete buttons if all rows are disabled
        # ----------------------------------------------------------
        if ( $t->are_all_disabled ) {
            foreach my $row ( 1 .. $t->rows ) {
                my $w = $t->get_widget( $row, 0 );
                next unless $w;
                $w->configure( -state => 'disabled' );
            }

        }

        # ----------------------------------------------------------
        # enable all the buttons if ANY of the elements in the
        # row are enabled
        # ----------------------------------------------------------
        else {
            foreach my $row ( 1 .. $t->rows ) {
                my $w = $t->get_widget( $row, 0 );
                $w->configure( -state => 'normal' ) if $w;
            }
        }

    }
    return $t->_cget('-bg_disabled');
}

# ===================================================================
# are all the entry buttons disabled?
# ===================================================================
sub are_all_disabled {
    my $t        = shift;
    my $disabled = $t->disabled;
    my $flag     = 1;
    $flag = 0 unless scalar(@$disabled);
    foreach my $d (@$disabled) {
        $flag = 0 unless $d;
    }
    return $flag;
}

# ===================================================================
# reconfigure the titles of the columns
# ===================================================================
sub titles {
    my ( $t, $r ) = @_;

    if ( defined $r ) {
        $t->_configure( -titles => $r );

        return unless $t->columns;
        my $row = 0;
        foreach my $c ( 1 .. $t->columns ) {
            my $w = $t->get_widget( $row, $c );
            if ($w) {
                $w->configure( -text => $r->[ $c - 1 ] );
            }
        }
    }
    return $t->_cget('-titles');
}

# ===================================================================
# change the column widths
# ===================================================================
sub colwidths {
    my ( $t, $r ) = @_;

    if ( defined $r ) {
        $t->_configure( -colwidths => $r );

        # go through each widget, and redefine the width
        return unless $t->columns;
        return unless $t->rows;
        foreach my $c ( 1 .. $t->columns ) {
            foreach my $row ( 0 .. $t->rows ) {

                my $w = $t->get_widget( $row, $c );
                if ($w) {
                    my $width = $r->[ $c - 1 ] || $t->{-defwidth} || 8;
                    $w->configure( -width => $width );
                }
            }
        }
    }
    return $t->_cget('-colwidths');
}

# ===================================================================
# insert header_row
# ===================================================================
sub _create_header_row {
    my $t = shift;
    $t->{-titleWidgets} = [];
    my $cols      = $t->columns;
    my $titles    = $t->titles;
    my $colwidths = $t->colwidths;

    foreach my $c ( 1 .. $cols ) {
        $titles->[ $c - 1 ] = '' unless $titles->[ $c - 1 ];
        $colwidths->[ $c - 1 ] = $t->cget('-defwidth')
          unless $colwidths->[ $c - 1 ];

        my $w = $t->pane->Label( -text  => $titles->[ $c - 1 ],
                                 -width => $colwidths->[ $c - 1 ] );

        $w->grid( -column => $c, -sticky => 'nwes', -row => 0 );
        $t->{-lookup}[0][$c] = $w;
        $t->{-reverse}{$w} = [ 0, $c ];
    }
}

# ===================================================================
# add empty_row
# ===================================================================
sub add_empty_row {
    my $t         = shift;
    my $row       = shift;
    my $colwidths = $t->colwidths;
    my $disabled  = $t->disabled;

    # for each column, add an entry box
    foreach my $c ( 1 .. $t->columns ) {

        $colwidths->[ $c - 1 ] = $t->cget('-defwidth')
          unless $colwidths->[ $c - 1 ];

        # if there is something already there, delete it!
        my $old = $t->{-lookup}[$row][$c];
        $old->destroy if $old;

        # make entry widget
        my $w = $t->pane->Entry(
                                 -width              => $colwidths->[ $c - 1 ],
                                 -bg                 => $t->cget('-bg_entry'),
                                 -disabledforeground => 'black',
                                 -relief =>'flat',
                               );
        if ( $disabled->[ $c - 1 ] ) {
            $w->configure( -state => 'disabled' );
        }
        $w->grid( -column => $c, -sticky => 'nwes', -row => $row );

        # key bindings for this entry widget
        $w->bind( "<Tab>",            [ \&_nextCell,   $t ] );
        $w->bind( "<Key-Return>",     [ \&_nextCell,   $t ] );
        $w->bind( "<Shift-Tab>",      [ \&_prevCell,   $t ] );
        $w->bind( "<Key-Left>",       [ \&_prevCell,   $t ] );
        $w->bind( "<Key-leftarrow>",  [ \&_prevCell,   $t ] );
        $w->bind( "<Key-Up>",         [ \&_prevRow,    $t ] );
        $w->bind( "<Key-uparrow>",    [ \&_prevRow,    $t ] );
        $w->bind( "<Key-Down>",       [ \&_nextRow,    $t ] );
        $w->bind( "<Key-downarrow>",  [ \&_nextRow,    $t ] );
        $w->bind( "<Key-Right>",      [ \&_nextCell,   $t ] );
        $w->bind( "<Key-rightarrow>", [ \&_nextCell,   $t ] );
        $w->bind( "<Button>",         [ \&_select_all, $t ] );

        # I want my bindings to happen BEFORE the class bindings
        $w->bindtags( [ ( $w->bindtags )[ 1, 0, 2, 3 ] ] );

        # save positional info
        $t->{-lookup}[$row][$c] = $w;
        $t->{-reverse}{$w} = [ $row, $c ];
    }

    # keep our row count up to date
    if ( $row > $t->rows ) {
        $t->configure( -rows => $row );
    }

    # add a 'delete button' in the first column
    $t->_put_delete($row);

    # if we have a row button, add that to last column
    if ( $t->cget("-buttoncmd") ) {
        my $b;
        $b = $t->pane->Button(
            -text    => $t->cget("-buttontext"),
            -command => [
                sub {
                    my $t    = shift;
                    my @data = $t->read_row($row);
                    $t->Callback( '-buttoncmd', @data );
                },
                $t
                        ]
        );

        $b->grid( -column => $t->columns + 1, -sticky => 'nwes', -row => $row );
    }

    # adjust height of pane
    my $ytot = 0;
    foreach my $row ( 0 .. $t->row ) {
        my $w = $t->get_widget( $row, 1 );
        next unless $w;
        $ytot += $w->reqheight;
    }
    $ytot += 2 * $t->cget('-border');
    $ytot += $t->pane->Subwidget('xscrollbar')->reqheight;
    $t->configure( -height => $ytot );
    $t->pane->configure( -height => $ytot );

}

# ===================================================================
# lookup tables subs
# ===================================================================
sub find_pos {
    my $t = shift;
    my $w = shift;
    if ($w) {
        return @{ $t->{-reverse}{$w} };
    }
    else {
        return;
    }
}

sub get_widget {
    my $t   = shift;
    my $row = shift;
    my $col = shift;
    return unless defined $col && defined $row;
    return $t->{-lookup}[$row][$col];
}

# ===================================================================
# put the 'delete' button at the beginning of a row
# ===================================================================

sub _put_delete {
    my ( $t, $row ) = @_;
    my $b;
    my $bg = $t->cget( -bg );
    if ($ex_photo) {
        $b = $t->pane->Button(
            -image               => $ex_photo,
            -relief              => 'flat',
            -command             => [ \&delete_row, $t, $row ],
            -highlightbackground => $bg,
            -highlightcolor      => $bg,
            -bg                  => $bg,

                             );
    }
    else {
        $b = $t->pane->Button(
                               -text    => "delete",
                               -relief  => 'flat',
                               -command => [ \&delete_row, $t, $row ],
                               -highlightbackground => $bg,
                               -highlightcolor      => $bg,
                               -bg                  => $bg,
                             );
    }

    $b->grid( -column => 0, -sticky => 'nwes', -row => $row );

    # save positional info
    $t->{-lookup}[$row][0] = $b;
    $t->{-reverse}{$b} = [ $row, 0 ];

    if ( $t->are_all_disabled ) {
        $b->configure( -state => 'disabled' );
    }

}

# ===================================================================
# delete a row
# ===================================================================
sub delete_row {
    my $t   = shift;
    my $row = shift;
    return unless $row;    # cannot delete the header row, sorry!

    # run user supplied callback first
    my @data = $t->read_row($row);
    $t->Callback( '-delete', \@data );

    # now remove the widgets and the row
    foreach my $c ( 0 .. $t->columns ) {
        my $w = $t->get_widget( $row, $c );
        undef $t->{-reverse}{$w};
        next unless $w;
        $w->destroy();
        undef $t->{-lookup}[$row][$c];
    }
}

# ===================================================================
# delete all rows, without callback
# ===================================================================
sub empty {
    my $t = shift;

    foreach my $r ( 1 .. $t->rows ) {
        foreach my $c ( 0 .. $t->columns ) {
            my $w = $t->get_widget( $r, $c );
            next unless $w;
            undef $t->{-reverse}{$w};
            $w->destroy();
            undef $t->{-lookup}[$r][$c];
        }
    }
    $t->configure( -rows => 0 );
    $t->add_empty_row(1);

}

# ===================================================================
# put data
# ===================================================================
sub put {
    my $t    = shift;
    my $row  = shift;
    my $col  = shift;
    my $data = shift;

    $data = defined $data ? $data : '';
    return if $row < 1;

    foreach my $row ( $t->rows + 1 .. $row ) {
        $t->add_empty_row($row);
        $t->configure( -rows => $row );
    }

    my $w = $t->get_widget( $row, $col );
    if ($w) {
        $w->configure( -text => $data );
    }

}

# ===================================================================
# put row
# ===================================================================
sub put_row {
    my $t   = shift;
    my $row = shift;

    return if $row < 1;

    foreach my $col ( 1 .. $t->columns ) {
        my $data = shift;
        $data = '' unless defined $data;

        foreach my $row ( $t->rows + 1 .. $row ) {
            $t->add_empty_row($row);
            $t->configure( -rows => $row );
        }

        my $w = $t->get_widget( $row, $col );
        if ($w) {
            $w->configure( -text => $data );
        }
    }
}

# ===================================================================
# put row
# ===================================================================
sub read_row {
    my $t   = shift;
    my $row = shift;
    $t->update;
    my @data;

    return if $row < 1;

    foreach my $col ( 1 .. $t->columns ) {
        my $w = $t->get_widget( $row, $col );
        if ($w) {
            push @data, $w->get;
        }
    }
    return @data;
}

# ===================================================================
# bindings for entry widget
# ===================================================================
sub _select_all {
    my ( $w, $t ) = @_;
    if ($w) {
        $w->focus();
        $w->selectionClear();
        $w->selectionRange( 0, 'end' );
        $w->break;
    }
}

# ----------------------------------------------------------------------
# move the focus to row/col... return false if no widget there
# ----------------------------------------------------------------------
sub _move_focus {
    my $t   = shift;
    my $row = shift;
    my $col = shift;
    my $w2  = $t->get_widget( $row, $col );
    if ($w2) {
        $t->pane->see($w2);
        $t->update;
        $w2->focus();
        $w2->selectionRange( 0, 'end' );
        return 1;
    }
    else {
        return 0;
    }
}

# ----------------------------------------------------------------------
# move next/prev
# ----------------------------------------------------------------------
sub _nextCell {
    my ( $w, $t ) = @_;

    # if all columns are disabled, do nothing
    if ( $t->are_all_disabled ) {
        $w->break;
        return;
    }

    $w->selectionClear();

    # get new postion info
    my ( $row, $col ) = $t->find_pos($w);
    return unless defined $row && defined $col;

    $col++;

    if ( $col > $t->columns ) {
        $row++;
        $col = 1;
    }

    if ( $row > $t->rows ) {
        $t->add_empty_row($row);
    }

    # move
    while ( $row <= $t->rows && !( $t->_move_focus( $row, $col ) ) ) {
        $row++;
    }

    # if we land on a disabled widget, keep moving
    my $disabled = $t->disabled || [];
    if ( $disabled->[ $col - 1 ] ) {
        my $w2 = $t->get_widget( $row, $col );
        _nextCell( $w2, $t );
        $w->break();
    }

    $w->break();

}

sub _prevCell {
    my ( $w, $t ) = @_;

    # if all rows are disabled, do nothing
    if ( $t->are_all_disabled ) {
        $w->break;
        return;
    }

    $w->selectionClear();

    # get new position info
    my ( $row, $col ) = $t->find_pos($w);
    my $col_current = $col;
    $col--;

    if ( $col < 1 ) {
        $row--;
        if ( $row < 1 ) {
            $row = 1;
            $col = 1;
        }
        else {
            $col = $t->columns;
        }
    }

    # if we land on a disabled widget, keep moving
    # unless it is the last one in the table
    my $disabled = $t->disabled;
    if ( $disabled->[ $col - 1 ] ) {

        # if we are not on the first row, just
        # go to prev Cell again
        if ( $row > 1 ) {
            my $w2 = $t->get_widget( $row, $col );
            _prevCell( $w2, $t );
            $w->break;
        }

        # if we are on the first row, are there any
        # non-disabled columns that we could still go to?
        while ( $col > 0 ) {
            if ( $disabled->[ $col - 1 ] ) {
                $col--;
            }
            else {
                last;
            }
        }
        $col = $col_current unless $col;

    }

    # move
    while ( $row >= 1 && !( $t->_move_focus( $row, $col ) ) ) {
        $row--;
    }

    $w->break();
}

# ----------------------------------------------------------------------
# move for up/down
# ----------------------------------------------------------------------
sub _nextRow {
    my ( $w, $t ) = @_;

    # if all rows are disabled, do nothing
    if ( $t->are_all_disabled ) {
        $w->break;
        return;
    }

    $w->selectionClear();

    my ( $row, $col ) = $t->find_pos($w);
    $row++;

    if ( $row > $t->rows ) {
        $t->add_empty_row($row);
    }

    # move
    while ( $row <= $t->rows && !( $t->_move_focus( $row, $col ) ) ) {
        $row++;
    }
    $w->break();
}

sub _prevRow {
    my ( $w, $t ) = @_;

    # if all rows are disabled, do nothing
    if ( $t->are_all_disabled ) {
        $w->break;
        return;
    }

    $w->selectionClear();

    my ( $row, $col ) = $t->find_pos($w);
    $row--;
    $row = 1 if $row < 1;

    while ( $row >= 1 && !( $t->_move_focus( $row, $col ) ) ) {
        $row--;
    }
    $w->break();
}

1;

