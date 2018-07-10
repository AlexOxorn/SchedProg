use Tk;
require Tk::TList;
require Tk::ROText;
use strict;

my $mw = MainWindow->new(-title => "Fonts");
$mw->minsize(700,400);
my $tl = $mw->Scrolled("TList", -font => ['Arial', '12'], -command => \&show_font)->
pack(-fill => 'both', -expand => 1);

# using a tlist, we have to insert each item individually
foreach (sort $mw->fontFamilies)
{
    $tl->insert('end', -itemtype => 'text', -text => $_);
}

MainLoop;

# called when user double clicks on a font name in the tlist.
sub show_font
{
    my ($index) = @_;
    my $name = $tl->entrycget($index, -text);
    my $top = $mw->Toplevel(-title => $name);
    my $text = $top->Scrolled("ROText", -wrap => 'none')
    ->pack(-expand => 1, -fill => 'both');
    
    $text->tagConfigure('number', -font => ['courier', '12']);
    
    # since we don't know what font they picked, we dynamically
    # create a tag w/that font formatting
    $text->tagConfigure('abc', -font => [$name, '18']);
    $text->insert('end', "abcdefghijklmnopqrstuvwxyz\
    nABCDEFGHIJKLMNOPQRSTUVWXYZ\n1234567890.;,;(*!?')\n\n", 'abc');
    
    foreach (qw/12 18 24 36 48 60 72/)
    {
        $text->tagConfigure("$name$_", -font => [$name, $_]);
        $text->insert('end', "$_ ", 'number');
        $text->insert('end',
        "The quick brown fox jumps over the lazy dog. 1234567890\n", "$name$_");
    }
}