#!/usr/bin/perl
use strict;
use warnings;

package AllocationGrid;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
use PerlLib::Colours;
use Tk::Dialog;
use Tk::Menu;
use Tk::LabEntry;
use Tk::Pane;

# ============================================================================
# globals
# ============================================================================
our $Fonts;
our $Colours;

my $header_colour1  = "#abcdef";
my $header_colour2  = Colour->lighten( 5, $header_colour1 );
my $very_light_grey = "#eeeeee";

# width of the data entry (fixed for now... maybe make it configurable
# at a later date)
my $width = 4;

# ============================================================================
# new
# ============================================================================

=head2 new

Creates the Grid.  Is a rather generic grid, even though it is called
AllocationGrid.  Could be repurposed for other things (maybe become a Tk widget)

B<Parameters>

* class - class type

* frame - Tk frame to draw on

* rows - how many rows do you want

* col_merge - array of sub headings 

Example, if you want this for your 2 heading rows
    
    +-------------+----------+--------------------+
    | heading1    | heading2 | heading3           |
    +------+------+----------+------+------+------+
    | sub1 | sub2 | sub1     | sub1 | sub2 | sub3 |
    +------+------+----------+------+------+------+

use col_merge = [2,1,3]

* data_entry_callback - a callback function called everytime
there data widget is modified.  row/col are sent as parameters
to the callback

B<Returns>

AllocationGrid object

=cut 

sub new {
    my $class     = shift;
    my $frame     = shift;
    my $rows      = shift;
    my $col_merge = shift;
    my $Colours   = shift;
    $Fonts = shift;

    my @col_merge           = @$col_merge;
    my $data_entry_callback = shift || sub { return 1; };
    my $self                = bless {}, $class;

    # ------------------------------------------------------------------------
    # some instance data we need to keep
    # ------------------------------------------------------------------------
    my %data_entry_widgets;
    my %data_widgets_rowcol;
    my @sub_header_widgets;
    my @header_widgets;
    my @row_widgets;

    $self->header_widgets( \@header_widgets );
    $self->sub_header_widgets( \@sub_header_widgets );
    $self->row_header_widgets( \@row_widgets );
    $self->entry_widgets( \%data_entry_widgets );
    $self->widgets_row_col( \%data_widgets_rowcol );

    # ------------------------------------------------------------------------
    # get rid of anything that is currently on this frame
    # ------------------------------------------------------------------------
    foreach my $w ( $frame->packSlaves ) {
        $w->destroy;
    }

    # ------------------------------------------------------------------------
    # make a 2x3 grid with frames for
    # blank | header | blank
    # teacher | data | totals
    # ------------------------------------------------------------------------
    my $pane = $frame->Frame( -bg => 'pink' );
    $pane->pack( -side => 'top', -expand => 1, -fill => 'both' );

    my $header_frame = $pane->Pane( -bg => "blue",   -sticky => 'nsew' );
    my $row_frame    = $pane->Pane( -bg => 'pink',   -sticky => 'nsew' );
    my $data_frame   = $pane->Pane( -bg => 'yellow', -sticky => 'nsew' );
    my $totals_frame = $pane->Pane( -bg => 'green',  -sticky => 'nsew' );
    $self->header_frame($header_frame);
    $self->data_frame($data_frame);
    $self->row_frame($row_frame);

    #$self->totals_frame($totals_frame);

    $header_frame->grid( -row => 0, -column => 1, -sticky => 'nsew' );
    $row_frame->grid( -row => 1, -column => 0, -sticky => 'nsew' );
    $data_frame->grid( -row => 1, - column => 1, -sticky => 'nsew' );
    $totals_frame->grid( -row => 1, -column => 2, -sticky => 'nsew' );
    $pane->gridColumnconfigure( 0, -weight => 0 );
    $pane->gridColumnconfigure( 1, -weight => 5 );
    $pane->gridColumnconfigure( 2, -weight => 0 );

    # ------------------------------------------------------------------------
    # make scrollbars
    # ------------------------------------------------------------------------
    my $horiz_scroll = $frame->Scrollbar(
        -orient       => 'horizontal',
        -activerelief => 'flat',
        -relief       => 'flat'
    );
    my $vert_scroll = $frame->Scrollbar(
        -orient       => 'vertical',
        -activerelief => 'flat',
        -relief       => 'flat'
    );

    my $scroll_horz_widgets = [ $header_frame, $data_frame ];
    $horiz_scroll->pack( -side => 'bottom', -expand => 1, -fill => 'x' );

    # configure widgets so scroll bar works properly
    foreach my $w (@$scroll_horz_widgets) {
        $w->configure(
            -xscrollcommand => sub {
                my (@args) = @_;
                $horiz_scroll->set(@args);
            },
        );
    }

    $horiz_scroll->configure(
        -command => sub {
            foreach my $w (@$scroll_horz_widgets) {
                $w->xview(@_);
            }
        }
    );

    # ------------------------------------------------------------------------
    # make the other stuff
    # ------------------------------------------------------------------------
    $self->make_header_columns($col_merge);
    $self->make_row_titles($rows);
    $self->make_data_grid( $rows, $col_merge, $data_entry_callback );

    return $self;

}

# ============================================================================
# make the header columns
# ============================================================================
sub make_header_columns {
    my $self      = shift;
    my $col_merge = shift;

    # merged header
    foreach my $header ( 0 .. @$col_merge - 1 ) {

        # frame to hold the merged header, and the sub-headings
        my $mini_frame =
          $self->header_frame->Frame( -bg => 'black' )->pack( -side => 'left' );

        # widget
        my $me = $mini_frame->Entry(
            -width   => $width,
            -relief  => 'flat',
            -bg      => $header_colour1,
            -justify => 'center',
            -font    => $Fonts->{small},

        )->pack( -side => 'top', -expand => 0, -fill => 'both' );

        # reset colours to normal after we disable the widget
        my $bg = $me->cget('-bg');
        my $fg = $me->cget('-fg');
        $me->configure( -state              => 'disabled' );
        $me->configure( -disabledbackground => $bg );
        $me->configure( -disabledforeground => $fg );

        # change colour every second merged header
        if ( $header % 2 ) {
            $me->configure( -disabledbackground => $header_colour2 );
        }

        # keep these widgets so that they can be configured later
        push @{ $self->header_widgets }, $me;

        # --------------------------------------------------------------------
        # subsections
        # --------------------------------------------------------------------
        foreach my $sub_section ( 1 .. $col_merge->[$header] ) {

            # frame within the mini-frame so we can stack 'left'
            my $hf2 =
              $mini_frame->Frame( -bg => 'blue' )->pack( -side => 'left' );

            # widget
            my $se = $hf2->Entry(
                -relief    => 'flat',
                -width     => $width,
                -justify   => 'center',
                -bg        => $header_colour1,
                -takefocus => 0,
                -font      => $Fonts->{small},

            )->pack( -side => 'left' );

            # reset colours to normal after we disable the widget
            my $bg = $se->cget('-bg');
            my $fg = $se->cget('-fg');
            $se->configure( -state              => 'disabled' );
            $se->configure( -disabledbackground => $bg );
            $se->configure( -disabledforeground => $fg );

            # change colour every second merged header
            if ( $header % 2 ) {
                $se->configure( -disabledbackground => $header_colour2 );
            }

            # keep these widgets so that they can be configured later
            push @{ $self->sub_header_widgets }, $se;
        }
    }

    return;
}

# ============================================================================
# row titles
# ============================================================================
sub make_row_titles {
    my $self = shift;
    my $rows = shift;

    foreach my $row ( 0 .. $rows - 1 ) {
        my $re = $self->row_frame->Entry(
            -takefocus => 0,
            -relief    => 'flat',
            -width     => 12,
            -font      => $Fonts->{small},
            -font      => $Fonts->{small},

        )->pack( -side => 'top' );

        # reset colours to normal after we disable the widget
        my $bg = $re->cget('-bg');
        my $fg = $re->cget('-fg');
        $re->configure( -state              => 'disabled' );
        $re->configure( -disabledbackground => $bg );
        $re->configure( -disabledforeground => $fg );

        push @{ $self->row_header_widgets }, $re;
    }

    return;
}

# ============================================================================
# data grid
# ============================================================================
sub make_data_grid {
    my $self      = shift;
    my $rows      = shift;
    my $col_merge = shift;
    my $callback  = shift;

    my %data;
    foreach my $row ( 0 .. $rows - 1 ) {
        my $df1 = $self->data_frame->Frame()
          ->pack( -side => 'top', -expand => 1, -fill => 'x' );

        # foreach header
        my $col = 0;
        foreach my $header ( 0 .. @$col_merge - 1 ) {

            # subsections
            foreach my $sub_section ( 1 .. $col_merge->[$header] ) {

                # data entry box
                my $de = $df1->Entry(
                    -relief          => 'flat',
                    -width           => $width,
                    -justify         => 'center',
                    -validate        => 'key',
                    -validatecommand => [ $callback, $row, $col ],
                    -invalidcommand => sub { $df1->bell },
                    -font           => $Fonts->{small},
                )->pack( -side => 'left' );

                # save row/column with dataentry, and vice-versa
                $self->entry_widgets->{$row}{$col} = $de;
                $self->widgets_row_col->{$de} = [ $row, $col ];

                # set colour in column to make it easier to read
                unless ( $header % 2 ) {
                    $de->configure( -bg => $very_light_grey );
                }

                # set bindings for navigation
                $de->bind( "<Tab>",           [ \&_move, $self, 'nextCell' ] );
                $de->bind( "<Key-Return>",    [ \&_move,  $self, 'nextRow' ] );
                $de->bind( "<Shift-Tab>",     [ \&_move, $self, 'prevCell' ] );
                $de->bind( "<Key-Up>",        [ \&_move,  $self, 'prevRow' ] );
                $de->bind( "<Key-uparrow>",   [ \&_move,  $self, 'prevRow' ] );
                $de->bind( "<Key-Down>",      [ \&_move,  $self, 'nextRow' ] );
                $de->bind( "<Key-downarrow>", [ \&_move,  $self, 'nextRow' ] );
                $de->bindtags( [ ( $de->bindtags )[ 1, 0, 2, 3 ] ] );

                $col++;
            }
        }
    }

    return;
}

# ============================================================================
# populate: assign textvariables to each of the entry widgets
# ============================================================================
sub populate {
    my $self            = shift;
    my $header_text     = shift;
    my $sub_header_text = shift;
    my $row_header_text = shift;
    my $data_vars       = shift;

    # the data grid
    foreach my $col ( 0 .. $self->num_cols -1 ) {
        foreach my $row ( 0 .. $self->num_rows  -1 ) {
            my $widget = $self->get_widget( $row, $col );
            $widget->configure( -textvariable => $data_vars->[$row][$col] )
              if $widget;
        }
    }

    # the header data
    my $i              = 0;
    my $header_widgets = $self->header_widgets;
    while ( my $var = shift @$header_text ) {
        $header_widgets->[$i]->configure( -textvariable => \$var );
        $i++;
    }
    
    # the sub header data
    $i = 0;
    my $sub_header_widgets = $self->sub_header_widgets;
    while ( my $var = shift @$sub_header_text ) {
        if ( exists $sub_header_widgets->[$i] ) {
            $sub_header_widgets->[$i]->configure( -textvariable => \$var );
            $i++;
        }
    }
    
    # the row header
    $i = 0;
    my $row_header_widgets = $self->row_header_widgets;
    while ( my $var = shift @$row_header_text ) {
        $row_header_widgets->[$i]->configure( -textvariable => \$var );
        $i++;
    }

}

# ============================================================================
# navigation routines
# ============================================================================

sub _move {
    my $w = shift;
    my $self = shift;
    my $where = shift;
    $w->selectionClear();
    my ($row,$col) = $self->get_row_col($w);
    
    $row = int_clamp(++$row,$self->num_rows) if $where eq 'nextRow';
    $row = int_clamp(--$row,$self->num_rows) if $where eq 'prevRow';
    $col = int_clamp(++$col,$self->num_cols) if $where eq 'nextCell';
    $col = int_clamp(--$col,$self->num_cols) if $where eq 'prevCell';
    
    my $e = $self->get_widget( $row, $col );
    $self->set_focus($e);
    $w->break();    
}

sub int_clamp {
    my $num = shift;
    my $max = shift;
    return 0 if $num < 0 ;
    return $max - 1 if $num > $max -1 ;
    return $num;
}
    

# ============================================================================
# Getters and setters
# ============================================================================

# ----------------------------------------------------------------------------
# frames
# ----------------------------------------------------------------------------
# Subroutine names are "header_frame", "data_frame", etc.
foreach my $frame (qw(header data row totals)) {
    no strict 'refs';
    *{ $frame . "_frame" } = sub {
        my $self = shift;
        $self->{ "-" . $frame . "_frame" } = shift if @_;
        return $self->{ "-" . $frame . "_frame" };
      }
}

# ----------------------------------------------------------------------------
# widgets
# ----------------------------------------------------------------------------
# Subroutine names are "header_widgets",  etc.
foreach my $widget (qw(header sub_header row_header)) {
    no strict 'refs';
    *{ $widget . "_widgets" } = sub {
        my $self = shift;
        $self->{ "-" . $widget . "_widgets" } = shift if @_;
        $self->{ "-" . $widget . "_widgets" } = []
          unless $self->{ "-" . $widget . "_widgets" };
        return $self->{ "-" . $widget . "_widgets" };
      }
}

# ----------------------------------------------------------------------------
# other getters and setters
# ----------------------------------------------------------------------------

sub entry_widgets {
    my $self = shift;
    $self->{-widgets} = {} unless $self->{-widgets};
    $self->{-widgets} = shift if @_;
    return $self->{-widgets};
}

sub widgets_row_col {
    my $self = shift;
    $self->{-widgets_row_col} = shift if @_;
    $self->{-widgets_row_col} = {} unless $self->{-widgets_row_col};
    return $self->{-widgets_row_col};
}

sub get_widget {
    my $self    = shift;
    my $row     = shift;
    my $col     = shift;
    my $widgets = $self->entry_widgets;
    return $widgets->{$row}{$col};
}

sub get_row_col {
    my $self     = shift;
    my $widget   = shift;
    my $row_cols = $self->widgets_row_col;
    return @{ $row_cols->{$widget} };
}

sub num_rows {
    my $self = shift;
    my $rows = $self->row_header_widgets;
    return scalar( @{$rows} );
}

sub num_cols {
    my $self = shift;
    my $cols = $self->sub_header_widgets;
    return scalar( @{$cols} );
}

1;

