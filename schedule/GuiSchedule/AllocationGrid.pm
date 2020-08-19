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

my $header_colour1           = "#abcdef";
my $header_colour2           = Colour->lighten( 5, $header_colour1 );
my $very_light_grey          = "#eeeeee";
my $row_col_indicator_colour = Colour->lighten( 5, "#cdefab" );
my $totals_header_colour     = Colour->new("lemonchiffon")->string;
my $totals_colour            = Colour->lighten( 5, $totals_header_colour );
my $fg_colour                = "black";
my $bg_colour                = "white";
my $needs_update_colour      = Colour->new("mistyrose")->string;
my $not_ok_colour            = $needs_update_colour;

# width of the data entry (fixed for now... maybe make it configurable
# at a later date)
my $width = 5;

# generic properties for entry widgets
my %entry_props;

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

* totals_merge - array to total columns sub headings

* data_entry_callback - a callback function called everytime
there data widget is modified.  row/col are sent as parameters
to the callback

B<Returns>

AllocationGrid object

=cut 

sub new {
    my $class        = shift;
    my $frame        = shift;
    my $rows         = shift;
    my $col_merge    = shift;
    my $totals_merge = shift;
    my $Colours      = shift;
    $Fonts = shift;

    my @col_merge              = @$col_merge;
    my $data_entry_callback    = shift || sub { return 1; };
    my $process_data_entry  = shift || sub{return 1};
    my $bottom_row_ok_callback = shift || sub { return 1; };

    my $self = bless {}, $class;
    $self->process_data_change($process_data_entry);


    # ------------------------------------------------------------------------
    # entry widget properties
    # ------------------------------------------------------------------------
    %entry_props = (
        -width              => $width,
        -relief             => 'flat',
        -borderwidth        => 1,
        -justify            => 'center',
        -font               => $Fonts->{small},
        -fg                 => $fg_colour,
        -disabledforeground => $fg_colour,
        -bg                 => $bg_colour,
        -disabledbackground => $bg_colour,
    );

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
    my $pane = $frame->Frame();
    $pane->pack( -side => 'top', -expand => 1, -fill => 'both' );

    # make the frames
    my $header_frame = $pane->Pane( -sticky => 'nsew' );
    my $row_frame    = $pane->Pane( -sticky => 'nsew' );
    my $data_frame   = $pane->Pane( -sticky => 'nsew' );
    my $totals_frame = $pane->Frame();
    my $totals_header_frame = $pane->Frame();
    my $bottom_header_frame = $pane->Pane( -sticky => 'nsew' );
    my $bottom_frame        = $pane->Pane( -sticky => 'nsew' );

    # save them
    $self->header_frame($header_frame);
    $self->data_frame($data_frame);
    $self->row_frame($row_frame);
    $self->totals_frame($totals_frame);
    $self->totals_header_frame($totals_header_frame);
    $self->bottom_header_frame($bottom_header_frame);
    $self->bottom_frame($bottom_frame);

    # configure the layout
    $header_frame->grid(
        -row    => 0,
        -column => 1,
        -sticky => 'nsew',
        -pady   => 2
    );
    $totals_header_frame->grid(
        -row    => 0,
        -column => 2,
        -padx   => 3,
        -pady   => 2
    );
    $row_frame->grid( -row => 1, -column => 0, -sticky => 'nsew', -padx => 3, );
    $data_frame->grid( -row => 1, - column => 1, -sticky => 'nsew', );
    $totals_frame->grid(
        -row    => 1,
        -column => 2,
        -sticky => 'nsew',
        -padx   => 3,

    );
    $bottom_header_frame->grid(
        -row    => 2,
        -column => 0,
        -sticky => 'nsew',
        -padx   => 3,
        -pady   => 2,
    );
    $bottom_frame->grid(
        -row    => 2,
        -column => 1,
        -sticky => 'nsew',
        -pady   => 2,
    );
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

    my $scroll_horz_widgets = [ $header_frame, $data_frame, $bottom_frame ];
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
    $self->make_total_grid( $rows, $totals_merge );
    $self->make_bottom_header();
    $self->make_bottom( $col_merge, $bottom_row_ok_callback );

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
        my $mini_frame = $self->header_frame->Frame()->pack( -side => 'left' );

        # widget
        my $me = $mini_frame->Entry(
            %entry_props,
            -disabledbackground => $header_colour1,
            -state              => 'disabled',
        )->pack( -side => 'top', -expand => 0, -fill => 'both' );

        # balloon
        my $balloon = $mini_frame->Balloon();
        push @{ $self->balloon_widgets }, $balloon;

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
            my $hf2 = $mini_frame->Frame()->pack( -side => 'left' );

            # widget
            my $se = $hf2->Entry(
                %entry_props,
                -disabledbackground => $header_colour1,
                -state              => 'disabled',
            )->pack( -side => 'left' );

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
# bottom row
# ============================================================================
sub make_bottom {
    my $self      = shift;
    my $col_merge = shift;
    my $is_ok     = shift;

    # merged header
    foreach my $header ( 0 .. @$col_merge - 1 ) {

        foreach my $sub_section ( 1 .. $col_merge->[$header] ) {

            # widget
            my $se;
            $se = $self->bottom_frame->Entry(
                %entry_props,
                -disabledbackground => $totals_colour,
                -state              => 'disabled',
                -validate           => 'key',
                -validatecommand    => sub {
                    my $n = shift;
                    if ( $is_ok->($n) ) {
                       $se->configure( -disabledbackground => $totals_colour );
                    }
                    else {
                        $se->configure( -disabledbackground => $not_ok_colour );
                    }
                    return 1;
                },
            )->pack( -side => 'left' );

            # keep these widgets so that they can be configured later
            push @{ $self->bottom_widgets }, $se;
        }
    }

    return;
}

# ============================================================================
# bottom row header
# ============================================================================
sub make_bottom_header {
    my $self = shift;

    # widget
    my $se = $self->bottom_header_frame->Entry(
        %entry_props,
        -state => 'disabled',
        -width => 12,
    )->pack( -side => 'top' );

    # keep these widgets so that they can be configured later
    push @{ $self->bottom_header_widgets }, $se;
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
            %entry_props,
            -width => 12,
            -state => 'disabled',
        )->pack( -side => 'top' );

        push @{ $self->row_header_widgets }, $re;
    }

    return;
}

# ============================================================================
# total grid and total header
# ============================================================================
sub make_total_grid {
    my $self         = shift;
    my $rows         = shift;
    my $totals_merge = shift;

    # totals header
    if (1) {
        foreach my $header ( 0 .. @$totals_merge - 1 ) {

            # frame to hold the totals header, and the sub-headings
            my $mini_frame =
              $self->totals_header_frame->Frame()->pack( -side => 'left' );

            # widget
            my $me = $mini_frame->Entry(
                %entry_props,
                -width              => $width + 1,
                -state              => 'disabled',
                -disabledbackground => $totals_header_colour,
            )->pack( -side => 'top', -expand => 0, -fill => 'both' );

            # keep these widgets so that they can be configured later
            push @{ $self->totals_header_widgets }, $me;

            # subsections
            foreach my $sub_section ( 1 .. $totals_merge->[$header] ) {

                # frame within the mini-frame so we can stack 'left'
                my $hf2 = $mini_frame->Frame()->pack( -side => 'left' );

                # widget
                my $se = $hf2->Entry(
                    %entry_props,
                    -width              => $width + 1,
                    -disabledbackground => $totals_header_colour,
                    -state              => 'disabled',

                )->pack( -side => 'left' );

                # keep these widgets so that they can be configured later
                push @{ $self->totals_sub_header_widgets }, $se;
            }
        }
    }

    # ------------------------------------------------------------------------
    # grid
    # ------------------------------------------------------------------------
    my %totals;
    foreach my $row ( 0 .. $rows - 1 ) {
        my $df1 = $self->totals_frame->Frame()
          ->pack( -side => 'top', -expand => 1, -fill => 'x' );

        # foreach header
        my $col = 0;
        foreach my $header ( 0 .. @$totals_merge - 1 ) {

            # subsections
            foreach my $sub_section ( 1 .. $totals_merge->[$header] ) {

                # data entry box
                my $de = $df1->Entry(
                    %entry_props,
                    -width              => $width + 1,
                    -state              => 'disabled',
                    -disabledbackground => $totals_colour,
                )->pack( -side => 'left' );

                # save row/column with totals entry
                $self->totals_widgets->{$row}{$col} = $de;

                $col++;
            }
        }
    }

    return;
}

# ============================================================================
# data grid
# ============================================================================
sub make_data_grid {
    my $self                = shift;
    my $rows                = shift;
    my $col_merge           = shift;
    my $data_entry_callback = shift;

    my %data;
    my $col = 0;
    foreach my $row ( 0 .. $rows - 1 ) {
        my $df1 = $self->data_frame->Frame()
          ->pack( -side => 'top', -expand => 1, -fill => 'x' );

        # foreach header
        $col = 0;
        foreach my $header ( 0 .. @$col_merge - 1 ) {

            # subsections
            foreach my $sub_section ( 1 .. $col_merge->[$header] ) {

                # data entry box
                my $de;
                $de = $df1->Entry(
                    %entry_props,
                    -validate        => 'key',
                    -validatecommand => [sub {
                        $de->configure( -bg => $needs_update_colour );
                        return $data_entry_callback->(  @_ );
                    },$row,$col],
                    -invalidcommand => sub { $df1->bell },
                )->pack( -side => 'left' );

                # save row/column with dataentry, and vice-versa
                $self->entry_widgets->{$row}{$col} = $de;
                $self->widgets_row_col->{$de} = [ $row, $col ];

                # set colour in column to make it easier to read
                my $colour = $de->cget( -bg );
                $colour = $very_light_grey unless $header % 2;
                $self->column_colours->[$col] = $colour;
                $de->configure( -bg => $colour );

               # set bindings for navigation
               #$de->bind( "<Key-Left>",       [ \&_move, $self, 'prevCell' ] );
               #$de->bind( "<Key-leftarrow>",  [ \&_move, $self, 'prevCell' ] );
               #$de->bind( "<Key-Right>",      [ \&_move, $self, 'nextCell' ] );
               #$de->bind( "<Key-rightarrow>", [ \&_move, $self, 'nextCell' ] );
                $de->bind( "<Tab>",           [ \&_move, $self, 'nextCell' ] );
                $de->bind( "<Key-Return>",    [ \&_move, $self, 'nextRow' ] );
                $de->bind( "<Shift-Tab>",     [ \&_move, $self, 'prevCell' ] );
                $de->bind( "<Key-Up>",        [ \&_move, $self, 'prevRow' ] );
                $de->bind( "<Key-uparrow>",   [ \&_move, $self, 'prevRow' ] );
                $de->bind( "<Key-Down>",      [ \&_move, $self, 'nextRow' ] );
                $de->bind( "<Key-downarrow>", [ \&_move, $self, 'nextRow' ] );

                $de->bind(
                    "<FocusIn>",
                    [
                        \&focus_changed, $self,
                        'focusIn',       $row_col_indicator_colour
                    ]
                );
                $de->bind( "<FocusOut>",
                    [ \&focus_changed, $self, 'focusOut' ] );
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
    my $self               = shift;
    my $header_text        = shift;
    my $balloon_text       = shift;
    my $sub_header_text    = shift;
    my $row_header_text    = shift;
    my $data_vars          = shift;
    my $total_header_texts = shift;
    my $total_sub_texts    = shift;
    my $total_vars         = shift;
    my $bottom_header_text = shift;
    my $bottom_row_vars    = shift;

    # bottom row
    my $bottom_header_widget = $self->bottom_header_widgets->[0];
    $bottom_header_widget->configure( -textvariable => $bottom_header_text );

    my $bottom_widgets = $self->bottom_widgets;
    foreach my $col ( 0 .. scalar(@$bottom_widgets) - 1 ) {
        $bottom_widgets->[$col]
          ->configure( -textvariable => $bottom_row_vars->[$col] );
    }

    # the totals header
    my $totals_widgets = $self->totals_header_widgets;
    foreach my $col ( 0 .. $self->num_totals_col - 1 ) {
        $totals_widgets->[$col]
          ->configure( -textvariable => \$total_header_texts->[$col] );
    }

    # the totals sub header
    my $totals_sub_widgets = $self->totals_sub_header_widgets;
    foreach my $col ( 0 .. $self->num_totals_sub_col - 1 ) {
        $totals_sub_widgets->[$col]
          ->configure( -textvariable => \$total_sub_texts->[$col] );
    }

    # the totals data
    foreach my $col ( 0 .. $self->num_totals_sub_col - 1 ) {

        foreach my $row ( 0 .. $self->num_rows - 1 ) {
            my $widget = $self->get_totals_widget( $row, $col );
            $widget->configure( -textvariable => $total_vars->[$row]->[$col] );
        }

    }

    # the data grid
    foreach my $col ( 0 .. $self->num_cols - 1 ) {
        foreach my $row ( 0 .. $self->num_rows - 1 ) {
            my $widget = $self->get_widget( $row, $col );

            # note... want the widget colour to go back to what it was,
            # even if the data has changed
            my $bg = $widget->cget( -bg );
            $widget->configure( -textvariable => $data_vars->[$row][$col] );
            $widget->configure( -bg           => $bg );
        }
    }

    # the header data
    my $i               = 0;
    my $header_widgets  = $self->header_widgets;
    my $balloon_widgets = $self->balloon_widgets;
    while ( my $var = shift @$header_text ) {
        $header_widgets->[$i]->configure( -textvariable => \$var );
        $balloon_widgets->[$i]
          ->attach( $header_widgets->[$i], -msg => $balloon_text->[$i] );
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
    my $w     = shift;
    my $self  = shift;
    my $where = shift;
    $w->selectionClear();
    my ( $row, $col ) = $self->get_row_col($w);

    my $old_row = $row;
    my $old_col = $col;

    $row = int_clamp( ++$row, $self->num_rows ) if $where eq 'nextRow';
    $row = int_clamp( --$row, $self->num_rows ) if $where eq 'prevRow';
    $col = int_clamp( ++$col, $self->num_cols ) if $where eq 'nextCell';
    $col = int_clamp( --$col, $self->num_cols ) if $where eq 'prevCell';

    my $e = $self->get_widget( $row, $col );
    $self->set_focus($e);

    # forces Tk to not continue applying any binding routines after this
    $w->break();
}

# ----------------------------------------------------------------------------
# what to do when the widget gets the focus
# ----------------------------------------------------------------------------
sub set_focus {
    my $self = shift;
    my $e    = shift;
    if ($e) {
        my ($r,$c) = $self->get_row_col($e);
        $self->header_frame->see($e);
        $self->data_frame->see($e);
        $self->bottom_frame->see($self->bottom_widgets->[$c]);
        $e->focus();
    }
}

# ----------------------------------------------------------------------------
# focus has changed - indicate what row/col we are on, callback process change
# ----------------------------------------------------------------------------
sub focus_changed {
    my $w      = shift;
    my $self   = shift;
    my $inout  = shift;
    my $colour = shift;

    # update selection
    if ( $inout eq 'focusIn' ) {
        $w->selectionRange( 0, 'end' );
    }
    else {
        $w->selectionClear();
    }

    # set data colour and totals colour
    my $dcolour = $colour || $bg_colour;
    my $tcolour = $colour;

    # are we processing a 'data change?'
    my $original_colour = $w->cget( -bg );
    my $data_changed =
      $original_colour eq $needs_update_colour && $inout eq 'focusOut';

    # get the widget
    my ( $row, $col ) = $self->get_row_col($w);

    # set colours for rows (data)
    my $col_colour = Colour->add( $dcolour, $self->column_colours->[$col] );
    foreach my $row ( 0 .. $self->num_rows - 1 ) {
        my $e = $self->get_widget( $row, $col );
        $e->configure( -bg => $col_colour );
    }

    # set colours for cols (data)
    foreach my $col ( 0 .. $self->num_cols - 1 ) {
        my $e = $self->get_widget( $row, $col );
        $col_colour = Colour->add( $dcolour, $self->column_colours->[$col] );
        $e->configure( -bg => $col_colour );
    }

    # set colour for row header
    my $widget = $self->row_header_widgets->[$row];
    $widget->configure( -disabledbackground => $dcolour );

    # set colours for totals row
    no warnings;
    if ($tcolour) {
        $tcolour = Colour->add( $tcolour, $totals_colour );
    }
    else {
        $tcolour = $totals_colour;
    }
    foreach my $col ( 0 .. $self->num_totals_sub_col - 1 ) {
        $widget = $self->totals_widgets->{$row}{$col};
        $widget->configure( -disabledbackground => $tcolour );
    }

    # callback (only if data has changed) (indicated by the current colour)
    $self->update_data( $row, $col ) if $data_changed;
}

# ----------------------------------------------------------------------------
# return a number between 0 and $max (non inclusive)
# ----------------------------------------------------------------------------
sub int_clamp {
    my $num = shift;
    my $max = shift;
    return 0 if $num < 0;
    return $max - 1 if $num > $max - 1;
    return $num;
}

# ============================================================================
# Getters and setters
# ============================================================================

# ----------------------------------------------------------------------------
# frames
# ----------------------------------------------------------------------------
# Subroutine names are "header_frame", "data_frame", etc.

foreach
  my $frame (qw(header data row totals totals_header bottom bottom_header))
{
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

foreach my $widget (
    qw(header balloon sub_header row_header totals_header totals_sub_header bottom_header bottom)
  )
{
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
sub process_data_change {
    my $self = shift;
    $self->{-process_data_change} = sub { return 1; }
      unless $self->{-process_data_change};
    $self->{-process_data_change} = shift if @_;
    return $self->{-process_data_change};
}

sub update_data {
    my $self = shift;
    my $row  = shift;
    my $col  = shift;
    $self->process_data_change->( $row, $col );
}

sub column_colours {
    my $self = shift;
    $self->{-col_colours} = [] unless $self->{-col_colours};
    $self->{-col_colours} = shift if @_;
    return $self->{-col_colours};
}

sub entry_widgets {
    my $self = shift;
    $self->{-widgets} = {} unless $self->{-widgets};
    $self->{-widgets} = shift if @_;
    return $self->{-widgets};
}

sub totals_widgets {
    my $self = shift;
    $self->{-twidgets} = {} unless $self->{-twidgets};
    $self->{-twidgets} = shift if @_;
    return $self->{-twidgets};
}

sub widgets_row_col {
    my $self = shift;
    $self->{-widgets_row_col} = shift if @_;
    $self->{-widgets_row_col} = {} unless $self->{-widgets_row_col};
    return $self->{-widgets_row_col};
}

sub widgets_row {
    my $self    = shift;
    my $row     = shift;
    my $widgets = $self->entry_widgets;
    my @widgets;
    foreach my $col ( 0 .. $self->num_cols - 1 ) {
        push @widgets, $widgets->{$row}{$col};
    }
    return \@widgets;
}

sub widgets_col {
    my $self    = shift;
    my $col     = shift;
    my $widgets = $self->entry_widgets;
    my @widgets;
    foreach my $row ( 0 .. $self->num_rows - 1 ) {
        push @widgets, $widgets->{$row}{$col};
    }
    return \@widgets;
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

sub get_totals_widget {
    my $self    = shift;
    my $row     = shift;
    my $col     = shift;
    my $widgets = $self->totals_widgets;
    return $widgets->{$row}{$col};
}

sub num_totals_col {
    my $self = shift;
    my $cols = $self->totals_header_widgets;
    return scalar( @{$cols} );
}

sub num_totals_sub_col {
    my $self = shift;
    my $cols = $self->totals_sub_header_widgets;
    return scalar( @{$cols} );
}

1;

