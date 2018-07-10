#!/usr/bin/perl
package Tk::DynamicTree;
use strict;


use Carp;
our $VERSION = 2.01;

use Tk::widgets qw/Tree/;
use base qw/Tk::Derived Tk::Tree/;

Construct Tk::Widget 'DynamicTree';

sub ClassInit {
    my ($class, $mw) = @_;

    $class->SUPER::ClassInit($mw);
    $mw->bind($class,'<Up>',[\&mybrowse,'Up']);
    $mw->bind($class,'<Down>',[\&mybrowse,'Down']);
    $mw->bind($class,'<Right>' =>[\&openclose,'Right']);
    $mw->bind($class,'<Left>'  =>[\&openclose,'Left']);

}

sub Populate {
    my ($self, $args) = @_;

    $self->SUPER::Populate($args);

    # opening a leaf (or node) in the tree
    my $opencmd_orig = $self->SUPER::cget(-opencmd);
    my $opencmd = [\&openbranch,$opencmd_orig];


    $self->ConfigSpecs(-children    => ['CALLBACK', undef, undef, undef ],
                       -onSelect    => ['CALLBACK', undef, undef, undef ],
                       -statusvar   => ['PASSIVE', undef, undef, undef],
                       -percentvar  => ['PASSIVE', undef, undef, undef],
                       -rightclick  => ['CALLBACK', undef,undef,undef],
                      );

}

# ----------------------------------------------------------------------
# sub openbranch -> callback for tree
# -> dynamically updates the next level of grandchildren, using
#    callback routine defined by '-children'
# ----------------------------------------------------------------------
sub OpenCmd {
    my $self = shift;
    (my $path) = @_;

    my $mw = $self->toplevel();
    my ($temp_var, $temp_per);

    my $status_ptr  = $self->cget(-statusvar);
    my $percent_ptr = $self->cget(-percentvar);

    if (ref $status_ptr  ne 'SCALAR') {$status_ptr  = \$temp_var;}
    if (ref $percent_ptr ne 'SCALAR') {$percent_ptr = \$temp_per;}


    # execute original tree method for opening a branch
    $self->SUPER::OpenCmd(@_);
    
    # only continue on if callback is defined
    return unless $self->cget(-children);

    # get a list of children of this branch (should this be leaf instead of child?)
    my @children = $self->infoChildren($path);

    # loop through all the children
    my $i = 0;
    my $sep = $self->cget(-separator);
    foreach my $child (@children) {
        my @grandkids;
        

        # update status variable
        (my $node) = $child =~ /^.*?([^\Q$sep\E]*)$/;
        if (length($child) < 30) {
            $$status_ptr = "Scanning node $child";
        }
        else {
            $$status_ptr = "Scanning node ... ".substr($child,-30);
        }
        $i++;
        $$percent_ptr = ($i/@children)*100;
        $mw->update() if $mw;

        # have grandchildren already been defined?
        next if $self->infoChildren($child);

        # define grandchildren for this child
        ($node) = $child =~ /([^\Q$sep\E]*)$/;
        @grandkids = $self->Callback(-children=>$self,$child);

        # avoid infinite loop
        if ($child =~ /\Q$sep$node$sep\E/) {
            @grandkids = (['<etc>',{-state=>'disabled'}]);
        }


        foreach my $kid (@grandkids) {
            my $newkid;
            my %kidhash;
            $newkid = $kid;
            if (ref $kid eq 'ARRAY') {
                $newkid = $kid->[0];
                if (ref $kid->[1] eq 'HASH') {
                    %kidhash = %{$kid->[1]};
                }
            }
            $self->add ("$child$sep$newkid",-text=>$newkid, %kidhash)
                    unless $self->infoExists("$child$sep$newkid");
            $self->hide('entry', "$child$sep$newkid");
        }


    }

    # done, update status variable and progress bar
    $self->autosetmode;
    $$status_ptr = "Done";
    $$percent_ptr = 0;
}

# ----------------------------------------------------------------------
# sub mybrowse
# - skips over selections when browsing if any one of the parent nodes
#   is hidden
# ----------------------------------------------------------------------
sub mybrowse {
    my $self = shift;
    my $dir = shift || '';  # direction, not directory
    my $sep = $self->cget(-separator);
    
    my $input = $self->selectionGet();
    $input = (ref $input) ? $input->[0] : $input;
    my $initial_selection = $input;

    # because of generic bug in HList, browsing also includes
    # nodes that are not hidden, but one of their parents are
    # - must skip these inputs
    if ($input and $dir) {
        $input = $self->infoNext($input) if $dir eq 'Down';
        $input = $self->infoPrev($input) if $dir eq 'Up';
        my @nodes = split (/\Q$sep\E/,$input);
        my $i=0;
        $i++ while ($i < @nodes and not $self->infoHidden(join($sep,@nodes[0..$i])));
        my $testnode = join($sep,@nodes[0..$i-1]);
        my $nextnode = $testnode;
        if ($testnode ne $input && $dir eq 'Down') {
            my $length = length($testnode);
            while (substr($nextnode,0,$length) eq $testnode) {
                $nextnode = $self->infoNext($nextnode);
            }
        }
        $input = $nextnode;
    }

    # this prevents scrolling off the edge (so to speak)
    $input = $input || $initial_selection;

    # change the selection to the current anchor point, after
    # deleting any selections currently present
    my @selects = $self->infoSelection;
    foreach my $select (@selects) {
        $self->selectionClear($select);
    }
    $self->selectionSet($input) if $input;
    $self->anchorClear();  # this makes the windows gui look less ugly
    $self->see($input) if $input;
}

# ----------------------------------------------------------------------
# sub openclose
# opens or closes depending on which arrow key was pressed
# ----------------------------------------------------------------------
sub openclose {
    my $self = shift;
    my $dir = shift || '';  # direction, not directory
    my $sep = $self->cget(-separator);

    my $input = $self->selectionGet();
    $input = (ref $input) ? $input->[0] : $input;
    return unless $input;

    $self->open($input) if $dir eq 'Right';
    $self->close($input) if $dir eq 'Left';

    $self->selectionSet($input);
    $self->anchorClear();
    $self->see($input);

    return;

}

sub selectionSet {
    my $self = shift;
    my $input = shift;
    return unless $self->infoExists($input);
    $self->SUPER::selectionSet($input);
    $self->Callback(-onSelect=>$self,$input);
}

# ======================================================================
# Expand Tree given a specific node to start from
# ======================================================================
{ my $goforit;
  my $treetext;
    sub ExpandTree {
        my $self     = shift;
        my $maxdepth = shift;
        my $keeptext = shift || 0;
        $treetext = '';

        my $selection = $self->selectionGet;
        my $select; $select = (ref $selection) ? $selection->[0] : $selection;
        return unless $select;

        $goforit = 1;
        return recursive_expand($self,$select,$maxdepth,$keeptext);
    }

    sub TreeText {
        return ExpandTree(@_,1);
    }

    sub recursive_expand {
        my $self = shift;
        my $path = shift;
        my $maxdepth = shift || 0;
        my $keeptext = shift || 0;
        my $curdepth = shift || 0;

        if ($self->getmode($path) ne 'none') {
            $self->open($path);
        }

        # bail out if curdepth exceeds max
        return if $maxdepth && $curdepth > $maxdepth;

        # keep text
        if ($keeptext) {
            my $sep = $self->cget(-separator);
            (my $ele = $path) =~ s/.*?([^$sep]*)$/$1/;
            $treetext = $treetext . "\n" . "  "x$curdepth . $ele;
        }

        # procreate
        $curdepth++;
        foreach my $child ($self->infoChildren($path)) {
            recursive_expand ($self,$child,
                              $maxdepth,$keeptext,$curdepth) if $goforit;
        }
        return $treetext;
    }

    sub CancelExpandTree {
        my $self = shift;
        $goforit = 0;
    }
}

# ======================================================================
# Collapse Tree given a specific node to start from
# ======================================================================
sub CollapseTree {
    my $self = shift;
    my $selection = $self->selectionGet;
    my $select; $select = (ref $selection) ? $selection->[0] : $selection;
    return unless $select;
    recursive_collapse($self,$select);
}
sub recursive_collapse {
    my $self = shift;
    my $path = shift;
    $self->close($path);
    foreach my $child($self->infoChildren($path)) {
        recursive_collapse($self,$child);
    }
}
1;
