#!/usr/bin/perl
package EasyDir;
use strict;

use Carp;
our $VERSION = 19.000.00;

use Tk::widgets qw/Tree/;
use base qw/Tk::Derived Tk::Tree/;

Construct Tk::Widget 'EasyDir';
my $default;

sub ClassInit {
    my ($class, $mw) = @_;
    $class->SUPER::ClassInit($mw);
}

sub Populate {
    my ($self, $args) = @_;
    my $inidir = delete $args->{-initialdir} ;
    $inidir = $inidir || './';

    $self->SUPER::Populate($args);

    $self->ConfigSpecs( -onSelect    => ['CALLBACK', undef, undef, undef ],
                        -indicatorcmd => ['CALLBACK', 'indicatorCmd', 'IndicatorCmd', 'IndicatorCmd'],
                        -imageopen  => ['PASSIVE','imageOpen','ImageOpen','openfold'],
                        -imageclose => ['PASSIVE','imageClose','ImageClose','folder'],
                        -initialdir => ['PASSIVE','initialDir','InitialDir',undef],
                        -openclose  => ['PASSIVE','openclose','Openclose',undef],
                        -editor     => ['PASSIVE','editor','Editor','nedit'],
                      );

    $self->configure( -separator => '/');
    $self->configure(-initialdir => $inidir);
    $self->configure(-drawbranch => 0);

    # browsing the tree
    $self->bind('<ButtonRelease-1>'=>[\&mybrowse,'']);
    $self->bind('<KeyPress-Up>'    =>[\&mybrowse,'Up']);
    $self->bind('<KeyPress-Down>'  =>[\&mybrowse,'Down']);

    # double clicking the tree
    $self->configure(-command=>[\&doubleclick,$self]);

}

# ----------------------------------------------------------------------
# sub doubleclick
# -> if dir, opens directory, if file, edits it using the default
#    editor
# ----------------------------------------------------------------------
sub doubleclick {
    my $self = shift;
    my $path = shift;
    my $ini  = $self->cget(-initialdir);
    my $ed   = $self->cget(-editor);
    if (-d "$ini/$path") {
        my $mode = $self->getmode($path);
        $self->Activate( $path, $mode );
        $self->Callback( -browsecmd => $path );
        return;
    }
    system ("$ed $ini/$path &");
    return;
}

# ----------------------------------------------------------------------
# sub openbranch
# -> reads the directory and populates tree
# ----------------------------------------------------------------------
sub OpenCmd {
    my $self = shift;
    (my $path) = @_;

    $self->Refresh($path);

    # make sure there is at least one child for a directory so that
    # an empty directory is more obvious
    my @children = $self->infoChildren( $path );
    unless (@children) {
        $self->add("$path/delmeordie",-text=>'<no entries>');
    }

    # execute original tree method for opening a branch
    $self->SUPER::OpenCmd(@_);

}

# ----------------------------------------------------------------------
# sub _get_dir
# -> returns the directory of the current path
# ----------------------------------------------------------------------
sub _get_dir {
    my $self = shift;
    my $path = shift;
    return $path if -d $path;
    (my $dir) = $path =~ m:^(.*)/: ;
    return $dir if -d $dir;
    return undef;
}

# ----------------------------------------------------------------------
# sub Refresh
# -> reads the directory and populates tree
# ----------------------------------------------------------------------
sub Refresh {
    my $self = shift;
    my $path = shift || "";

    # get a list of children of this branch (should this be leaf instead of child?)
    my @children = $self->infoChildren("$path");
    my %old = map {$_,1} @children;

    # get a directory listing (go up one dir if $path is a file)
    my $root = $self->cget(-initialdir);
    my $full_path = $self->_get_dir("$root/$path");
    (my $half_path) = $full_path =~ m:^\Q$root\E/(.*)$:;
    $half_path .= '/' if $half_path;
    return unless $full_path;        # should handle this error better, but...?

    opendir DIR, "$full_path" or return;
    my %current = map {("$half_path$_",1)} readdir DIR;
    $self->update();
    close DIR;

    # make two lists, one of directories, one of files
    my %dirs;
    foreach my $ele (sort (@children, keys %current)) {
        next unless -d $ele;
        $dirs{$ele}++;
    }
    my %files;
    foreach my $ele (sort (@children, keys %current)) {
        next if -d $ele;
        $files{$ele}++;
    }

    # loop through all the children, and remove those that no longer
    # exist, adding those that do exist
    my $old_ele = '';
    foreach my $ele (sort keys %dirs, sort keys %files) {

        $self->update();
        (my $name) = $ele =~ m:([^/]*$):;
        next if $name =~ /^\./;

        # if ele exists in old but not new, remove it
        if (exists $old{$ele} && not exists $current{$ele}) {
            $self->delete('offsprings',$ele);
            $self->delete('entry',$ele);
            next;
        }

        # if ele exits in new, but not old, add it
        if (exists $current{$ele} && not exists $old{$ele}) {
            if ($old_ele) {
                $self->add($ele,-text=>"$name",-after=>$old_ele) ;
            }
            else {
                $self->add($ele,-text=>"$name",-at=>0) ;
            }
        }

        $old_ele = $ele;
    }


    $self->autosetmode();
}

# ----------------------------------------------------------------------
# sub mybrowse
# - skips over selections when browsing if any one of the parent nodes
#   is hidden
# ----------------------------------------------------------------------
sub mybrowse {
    my $self = shift;
    my $dir = shift || '';  # direction, not directory

    my $input = $self->infoAnchor;

    # because of generic bug in HList, browsing also includes
    # nodes that are not hidden, but one of their parents are
    # - must skip these inputs
    if ($input and $dir) {
        my @nodes = split (/\./,$input);
        my $i=0;
        $i++ while ($i < @nodes and not $self->infoHidden(join('.',@nodes[0..$i])));
        my $testnode = join('.',@nodes[0..$i-1]);
        my $nextnode = $testnode;
        if ($testnode ne $input && $dir eq 'Down') {
            my $length = length($testnode);
            while (substr($nextnode,0,$length) eq $testnode) { 
                $nextnode = $self->infoNext($nextnode);
            }
        }
        $input = $nextnode;
        $self->anchorSet($input) if $input;
    }

    # change the selection to the current anchor point, after
    # deleting any selections currently present
    my @selects = $self->infoSelection;  
    foreach my $select (@selects) {
        $self->selectionClear($select);
    }
    $self->selectionSet($input) if $input;
}                            

# =================================================================================
# overide Tree methods that specifically refer to 'plus' and 'minus' icons
# and make them more generic
# =================================================================================
sub IndicatorCmd {
    my( $self, $path, $event ) = @_;

    if( $event eq '<Activate>' ) {
        my $mode = $self->getmode($path);
        $self->Activate( $path, $mode );
        $self->Callback( -browsecmd => $path );
    }
}

sub getmode {
    my( $self, $path ) = @_;

    my $fullpath = $self->cget(-initialdir)."/$path";

    return( 'none' ) unless -d $fullpath;

    my $img = $self->_indicator_image( $path );
    return( 'open' ) if $img eq $self->cget(-imageclose);  # ready to be opened
    return( 'close' );                          
}

sub setmode {
    my ($self,$path,$mode) = @_;
    
    my $fullpath = $self->cget(-initialdir)."/$path";
    
    if (-d $fullpath) {
        $mode = 'closed';   # default condition
        my @args;
        push(@args,$path) if defined $path;
        my @children = $self->infoChildren( @args );
        
        if ( @children ) {
            foreach my $c (@children) {
                $mode = 'opened' unless $self->infoHidden( $c );
                $self->setmode( $c );
            }
        }
    }
    else {
        $mode = 'none';
    }

    if (defined $path) {
    
        if ( $mode eq 'closed' ) {
            $self->_indicator_image( $path, $self->cget(-imageclose) );
        }
        
        elsif ( $mode eq 'opened' ) {
            $self->_indicator_image( $path, $self->cget(-imageopen) );
        }

        elsif( $mode eq 'none' ) {
            (my $ext) = $path =~ /\.(.*)$/;
            my $default;
            eval {$default = $ext if $self->Getimage($ext);};
            $default = $default || 'defaultfile';
            $self->_indicator_image( $path, $default );
        }
    }
}


sub Activate {
 
    my( $self, $path, $mode ) = @_;
    
    if ( $mode eq 'open' ) {
        $self->Callback( -opencmd => $path );
        $self->_indicator_image( $path, $self->cget(-imageopen) );

    }

    
    elsif ( $mode eq 'close' ) {
        $self->Callback( -closecmd => $path );
        $self->_indicator_image( $path, $self->cget(-imageclose) );

    }

 
    else {
    }
}

$default = << 'end-of-default';
/* XPM */
static char * Icon_xpm[] = {
"32 32 4 1",
"    c #FFFFFFFFFFFF",
".   c #000000000000",
"b   c #00000000FFFF",
"g   c #0000FFFF0000",
"................................",
".gggggggggggggggggggggggggggggg.",
".gggggggggggggggggggggggggggggg.",
".gg                          bb.",
".gg  ................   ...  bb.",
".gg  ................   ...  bb.",
".gg                          bb.",
".gg                          bb.",
".gg  .....                   bb.",
".gg  .....                   bb.",
".gg                          bb.",
".gg                          bb.",
".gg  ....................    bb.",
".gg  ....................    bb.",
".gg                          bb.",
".gg                          bb.",
".gg  ....   ...........      bb.",
".gg  ....   ...........      bb.",
".gg                          bb.",
".gg                          bb.",
".gg  ..........              bb.",
".gg  ..........              bb.",
".gg                          bb.",
".gg                          bb.",
".gg  ....                    bb.",
".gg  ....                    bb.",
".gg                          bb.",
".gg                          bb.",
".gg                          bb.",
".bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.",
".bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.",
"................................"};
end-of-default


1;
